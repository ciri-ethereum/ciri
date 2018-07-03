# frozen_string_literal: true

# Copyright (c) 2018, by Jiang Jinyang. <https://justjjy.com>
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
require 'ciri/evm/state'
require 'ciri/evm'
require 'ciri/types/account'
require 'ciri/forks/frontier'
require 'ciri/utils'
require 'ciri/db/backend/memory'

RSpec.describe Ciri::EVM do

  before(:all) do
    prepare_ethereum_fixtures
  end

  parse_account = proc do |address, v|
    balance = Ciri::Utils.big_endian_decode Ciri::Utils.to_bytes(v["balance"])
    nonce = Ciri::Utils.big_endian_decode Ciri::Utils.to_bytes(v["nonce"])
    storage = v["storage"].map do |k, v|
      [Ciri::Utils.to_bytes(k), Ciri::Utils.to_bytes(v).rjust(32, "\x00".b)]
    end.to_h
    [Ciri::Types::Account.new(balance: balance, nonce: nonce), storage]
  end

  run_test_case = proc do |test_case, prefix: nil, tags: {}|
    test_case.each do |name, t|

      it "#{prefix} #{name}", **tags do
        db = Ciri::DB::Backend::Memory.new
        state = Ciri::EVM::State.new(db)
        # pre
        t['pre'].each do |address, v|
          address = Ciri::Utils.to_bytes(address)
          account, storage = parse_account[address, v]
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

        ms = Ciri::EVM::MachineState.new(gas_remain: gas, pc: 0, stack: [], memory: "\x00".b * 256, memory_item: 0)
        instruction = Ciri::EVM::Instruction.new(address: address, origin: origin, price: gas_price, sender: caller,
                                                 bytes_code: code, value: value, data: data)
        block_info = env && Ciri::EVM::BlockInfo.new(
          coinbase: env['currentCoinbase'],
          difficulty: env['currentDifficulty'],
          gas_limit: env['currentGasLimit'],
          number: env['currentNumber'],
          timestamp: env['currentTimestamp'],
        )

        fork_config = Ciri::Forks::Frontier.fork_config
        vm = Ciri::EVM::VM.new(state: state, machine_state: ms,
                               instruction: instruction, block_info: block_info, fork_config: fork_config)

        # ignore exception
        vm.run(ignore_exception: true)
        next unless t['post']
        # post
        output = t['out'].yield_self {|out| out && Ciri::Utils.to_bytes(out)}
        if output
          # padding vm output, cause testcases return length is uncertain
          vm_output = (vm.output || '').rjust(output.size, "\x00".b)
          expect(vm_output).to eq output
        end

        gas_remain = t['gas'].yield_self {|gas_remain| gas_remain && Ciri::Utils.big_endian_decode(Ciri::Utils.to_bytes(gas_remain))}
        expect(vm.machine_state.gas_remain).to eq gas_remain if gas_remain

        state = vm.state
        t['post'].each do |address, v|
          address = Ciri::Utils.to_bytes(address)
          account, storage = parse_account[address, v]
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

  slow_tests = %w{fixtures/VMTests/vmPerformance}.map {|f| [f, true]}.to_h

  Dir.glob("fixtures/VMTests/*").each do |topic|
    tags = {}

    # add slow_tests tag
    if slow_tests.include? topic
      tags = {slow_tests: true}
    end

    Dir.glob("#{topic}/*.json").each do |t|
      run_test_case[JSON.load(open t), prefix: topic, tags: tags]
    end
  end

end
