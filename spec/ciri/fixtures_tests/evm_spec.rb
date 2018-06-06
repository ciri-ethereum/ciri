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
require 'ciri/evm'
require 'ciri/evm/account'
require 'ciri/evm/forks/frontier'
require 'ciri/utils'
require 'ciri/utils/memory_kv_store'

RSpec.describe Ciri::EVM do

  before(:all) do
    prepare_ethereum_fixtures
  end

  parse_account = proc do |address, v|
    address = Ciri::Utils.hex_to_data(address)
    balance = Ciri::Utils.big_endian_decode Ciri::Utils.hex_to_data(v["balance"])
    nonce = Ciri::Utils.big_endian_decode Ciri::Utils.hex_to_data(v["nonce"])
    storage = v["storage"].map do |k, v|
      [Ciri::Utils.hex_to_data(k), Ciri::Utils.hex_to_data(v).rjust(32, "\x00".b)]
    end.to_h
    Ciri::EVM::Account.new(address: address, balance: balance, nonce: nonce, storage: storage)
  end

  run_test_case = proc do |test_case, prefix: nil|
    test_case.each do |name, t|

      it "#{prefix} #{name}" do
        state = Ciri::Utils::MemoryKVStore.new
        # pre
        t['pre'].each do |address, v|
          account = parse_account[address, v]
          state[account.address] = account
        end
        # env
        # exec
        gas = Ciri::Utils.big_endian_decode Ciri::Utils.hex_to_data(t['exec']['gas'])
        address = Ciri::Utils.hex_to_data(t['exec']['address'])
        origin = Ciri::Utils.hex_to_data(t['exec']['origin'])
        caller = Ciri::Utils.hex_to_data(t['exec']['caller'])
        gas_price = Ciri::Utils.big_endian_decode Ciri::Utils.hex_to_data(t['exec']['gasPrice'])
        code = Ciri::Utils.hex_to_data(t['exec']['code'])
        value = Ciri::Utils.hex_to_data(t['exec']['value'])
        data = Ciri::Utils.hex_to_data(t['exec']['data'])

        ms = Ciri::EVM::MachineState.new(gas_remain: gas, pc: 0, stack: [], memory: "\x00".b * 256, memory_item: 0)
        instruction = Ciri::EVM::Instruction.new(address: address, origin: origin, price: gas_price, sender: caller,
                                                 bytes_code: code, value: value, data: data)
        fork_config = Ciri::EVM::Forks::Frontier.new_fork_config
        vm = Ciri::EVM::VM.new(state: state, machine_state: ms, instruction: instruction, fork_config: fork_config)
        vm.run
        next unless t['post']
        # post
        output = t['out'].yield_self {|out| out && Ciri::Utils.hex_to_data(out)}
        expect(vm.output || '').to eq output if output

        gas_remain = t['gas'].yield_self {|gas_remain| gas_remain && Ciri::Utils.big_endian_decode(Ciri::Utils.hex_to_data(gas_remain))}
        expect(vm.machine_state.gas_remain).to eq gas_remain if gas_remain

        t['post'].each do |address, v|
          account = parse_account[address, v]
          vm_account = state[account.address]
          storage = account.storage.map {|k, v| [Ciri::Utils.data_to_hex(k), Ciri::Utils.data_to_hex(v)]}.to_h
          vm_storage = vm_account.storage.map {|k, v| [Ciri::Utils.data_to_hex(k), Ciri::Utils.data_to_hex(v)]}.to_h
          expect(vm_storage).to eq storage
          expect(vm_account).to eq account
        end
      end

    end
  end

  path = 'fixtures/VMTests/vmArithmeticTest'
  # vmArithmeticTest
  Dir.glob("#{path}/*.json").each {|t| run_test_case[JSON.load(open t), prefix: 'vmArithmeticTest']}
end
