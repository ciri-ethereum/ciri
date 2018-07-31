# frozen_string_literal: true

# Copyright 2018 Jiang Jinyang <https://justjjy.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require 'spec_helper'
require 'ciri/evm/state'
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

  parse_account = proc do |address, v|
    balance = Ciri::Utils.big_endian_decode Ciri::Utils.to_bytes(v["balance"])
    nonce = Ciri::Utils.big_endian_decode Ciri::Utils.to_bytes(v["nonce"])
    storage = v["storage"].map do |k, v|
      [Ciri::Utils.hex_to_number(k), Ciri::Utils.hex_to_number(v)]
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
