# frozen_string_literal: true

# Copyright (c) 2018 by Jiang Jinyang <jjyruby@gmail.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


require 'spec_helper'
require 'ciri/state'
require 'ciri/evm'
require 'ciri/evm/execution_context'
require 'ciri/types/account'
require 'ciri/forks/frontier'
require 'ciri/utils'
require 'ciri/db/backend/memory'

RSpec.describe Ciri::EVM do

  before(:all) do
    prepare_ethereum_fixtures
  end

  run_test_case = proc do |test_case, prefix: nil|
    test_case.each do |name, t|

      it "#{prefix} #{name}" do
        db = Ciri::DB::Backend::Memory.new
        state = Ciri::State.new(db)
        # pre
        t['pre'].each do |address, account_hash|
          address = Ciri::Utils.to_bytes(address)
          account, _code, storage = parse_account(account_hash)
          state.set_balance(address, account.balance)
          state.set_nonce(address, account.nonce)
          storage.each do |key, value|
            state.store(address, key, value)
          end
        end
        # env
        # exec
        gas = Ciri::Utils.big_endian_decode Ciri::Utils.to_bytes(t['exec']['gas'])
        address = Ciri::Utils.to_bytes(t['exec']['address'])
        origin = Ciri::Utils.to_bytes(t['exec']['origin'])
        caller = Ciri::Utils.to_bytes(t['exec']['caller'])
        gas_price = Ciri::Utils.big_endian_decode Ciri::Utils.to_bytes(t['exec']['gasPrice'])
        code = Ciri::Utils.to_bytes(t['exec']['code'])
        value = Ciri::Utils.to_bytes(t['exec']['value'])
        data = Ciri::Utils.to_bytes(t['exec']['data'])
        env = t['env'] && t['env'].map {|k, v| [k, Ciri::Utils.to_bytes(v)]}.to_h

        instruction = Ciri::EVM::Instruction.new(address: address, origin: origin, price: gas_price, sender: caller,
                                                 bytes_code: code, value: value, data: data)
        block_info = env && Ciri::EVM::BlockInfo.new(
          coinbase: env['currentCoinbase'],
          difficulty: env['currentDifficulty'],
          gas_limit: env['currentGasLimit'],
          number: env['currentNumber'],
          timestamp: env['currentTimestamp'],
        )

        fork_schema = Ciri::Forks::Frontier::Schema.new
        context = Ciri::EVM::ExecutionContext.new(instruction: instruction, gas_limit: gas,
                                                  block_info: block_info, fork_schema: fork_schema)
        vm = Ciri::EVM::VM.new(state: state, burn_gas_on_exception: false)

        # ignore exception
        vm.with_context(context) do
          vm.run(ignore_exception: true)
        end

        next unless t['post']
        # post
        output = t['out'].yield_self {|out| out && Ciri::Utils.to_bytes(out)}
        if output
          # padding vm output, cause testcases return length is uncertain
          vm_output = (context.output || '').rjust(output.size, "\x00".b)
          expect(vm_output).to eq output
        end

        remain_gas = t['gas'].yield_self {|remain_gas| remain_gas && Ciri::Utils.big_endian_decode(Ciri::Utils.to_bytes(remain_gas))}
        expect(context.remain_gas).to eq remain_gas if remain_gas

        state = vm.state
        t['post'].each do |address, account_hash|
          address = Ciri::Utils.to_bytes(address)
          account, code, storage = parse_account(account_hash)
          vm_account = state.find_account(address)

          storage.each do |k, v|
            data = state.fetch(address, k)
            expect(Ciri::Utils.to_hex(data)).to eq Ciri::Utils.to_hex(v)
          end

          expect(vm_account.nonce).to eq account.nonce
          expect(vm_account.balance).to eq account.balance
          expect(vm_account.code_hash).to eq account.code_hash
        end
      end

    end
  end

  Dir.glob("fixtures/VMTests/*").each do |topic|
    Dir.glob("#{topic}/*.json").each do |t|
      run_test_case[JSON.load(open t), prefix: topic]
    end
  end

end
