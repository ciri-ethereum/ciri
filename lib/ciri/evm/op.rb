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


require 'ciri/utils'
require 'ciri/utils/number'
require 'ciri/types/address'

module Ciri
  class EVM

    # OP module include all EVM operations
    module OP
      include Types

      OPERATIONS = {}

      Operation = Struct.new(:name, :code, :inputs, :outputs, :handler, keyword_init: true) do
        def call(*args)
          handler.call(*args) if handler
        end
      end

      class << self
        # define VM operation
        # this method also defined a constant under OP module
        def def_op(name, code, inputs, outputs, &handler)
          OPERATIONS[code] = Operation.new(name: name.to_s, code: code, inputs: inputs, outputs: outputs,
                                           handler: handler).freeze
          const_set(name, code)
          code
        end

        def get(code)
          OPERATIONS[code]
        end

        def input_count(code)
          get(code)&.inputs
        end

        def output_count(code)
          get(code)&.outputs
        end
      end

      MAX_INT = Utils::Number::UINT_256_CEILING

      # basic operations
      def_op :STOP, 0x00, 0, 0
      def_op :ADD, 0x01, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer)
        vm.push((a + b) % MAX_INT)
      end

      def_op :MUL, 0x02, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer)
        vm.push((a * b) % MAX_INT)
      end

      def_op :SUB, 0x03, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer)
        vm.push((a - b) % MAX_INT)
      end

      def_op :DIV, 0x04, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer)
        vm.push((b.zero? ? 0 : a / b) % MAX_INT)
      end

      def_op :SDIV, 0x05, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer).map {|n| Utils::Number.unsigned_to_signed n}
        value = b.zero? ? 0 : a.abs / b.abs
        pos = (a > 0) ^ (b > 0) ? -1 : 1
        vm.push(Utils::Number.signed_to_unsigned(value * pos) % MAX_INT)
      end

      def_op :MOD, 0x06, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer)
        vm.push(b.zero? ? 0 : a % b)
      end

      def_op :SMOD, 0x07, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer).map {|n| Utils::Number.unsigned_to_signed n}
        value = b.zero? ? 0 : a.abs % b.abs
        pos = a > 0 ? 1 : -1
        vm.push(Utils::Number.signed_to_unsigned(value * pos))
      end

      def_op :ADDMOD, 0x08, 3, 1 do |vm|
        a, b, c = vm.pop_list(3, Integer)
        value = c.zero? ? 0 : (a + b) % c
        vm.push(value % MAX_INT)
      end

      def_op :MULMOD, 0x09, 3, 1 do |vm|
        a, b, c = vm.pop_list(3, Integer)
        vm.push(c.zero? ? 0 : (a * b) % c)
      end

      def_op :EXP, 0x0a, 2, 1 do |vm|
        base, x = vm.pop_list(2, Integer)
        vm.push(base.pow(x, MAX_INT))
      end

      # not sure how to handle signextend, copy algorithm from py-evm
      def_op :SIGNEXTEND, 0x0b, 2, 1 do |vm|
        bits, value = vm.pop_list(2, Integer)

        if bits <= 31
          testbit = bits * 8 + 7
          sign_bit = (1 << testbit)

          if value & sign_bit > 0
            result = value | (MAX_INT - sign_bit)
          else
            result = value & (sign_bit - 1)
          end

        else
          result = value
        end

        vm.push(result % MAX_INT)
      end

      def_op :LT, 0x10, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer)
        vm.push a < b ? 1 : 0
      end

      def_op :GT, 0x11, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer)
        vm.push a > b ? 1 : 0
      end

      def_op :SLT, 0x12, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer).map {|i| Utils::Number.unsigned_to_signed i}
        vm.push a < b ? 1 : 0
      end

      def_op :SGT, 0x13, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer).map {|i| Utils::Number.unsigned_to_signed i}
        vm.push a > b ? 1 : 0
      end

      def_op :EQ, 0x14, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer)
        vm.push a == b ? 1 : 0
      end

      def_op :ISZERO, 0x15, 1, 1 do |vm|
        a = vm.pop(Integer)
        vm.push a == 0 ? 1 : 0
      end

      def_op :AND, 0x16, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer)
        vm.push a & b
      end

      def_op :OR, 0x17, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer)
        vm.push a | b
      end

      def_op :XOR, 0x18, 2, 1 do |vm|
        a, b = vm.pop_list(2, Integer)
        vm.push a ^ b
      end

      def_op :NOT, 0x19, 1, 1 do |vm|
        signed_number = Utils::Number.unsigned_to_signed vm.pop(Integer)
        vm.push Utils::Number.signed_to_unsigned(~signed_number)
      end

      def_op :BYTE, 0x1a, 2, 1 do |vm|
        pos, value = vm.pop_list(2, Integer)
        if pos >= 32
          result = 0
        else
          result = (value / 256.pow(31 - pos)) % 256
        end
        vm.push result
      end

      # 20s: sha3
      def_op :SHA3, 0x20, 2, 1 do |vm|
        pos, size = vm.pop_list(2, Integer)
        hashed = Ciri::Utils.keccak vm.memory_fetch(pos, size)
        vm.extend_memory(pos, size)
        vm.push hashed
      end

      # 30s: environment operations
      def_op :ADDRESS, 0x30, 0, 1 do |vm|
        vm.push(vm.instruction.address)
      end

      def_op :BALANCE, 0x31, 1, 1 do |vm|
        address = vm.pop(Address)
        account = vm.find_account(address)
        vm.push(account.balance)
      end

      def_op :ORIGIN, 0x32, 0, 1 do |vm|
        vm.push vm.instruction.origin
      end

      def_op :CALLER, 0x33, 0, 1 do |vm|
        vm.push vm.instruction.sender
      end

      def_op :CALLVALUE, 0x34, 0, 1 do |vm|
        vm.push vm.instruction.value
      end

      def_op :CALLDATALOAD, 0x35, 1, 1 do |vm|
        start = vm.pop(Integer)
        vm.push(vm.get_data(start, 32))
      end

      def_op :CALLDATASIZE, 0x36, 0, 1 do |vm|
        vm.push vm.instruction.data.size
      end

      def_op :CALLDATACOPY, 0x37, 3, 0 do |vm|
        mem_pos, data_pos, size = vm.pop_list(3, Integer)
        data = vm.get_data(data_pos, size)
        vm.extend_memory(mem_pos, size)
        vm.memory_store(mem_pos, size, data)
      end

      def_op :CODESIZE, 0x38, 0, 1 do |vm|
        vm.push vm.instruction.bytes_code.size
      end

      def_op :CODECOPY, 0x39, 3, 0 do |vm|
        mem_pos, code_pos, size = vm.pop_list(3, Integer)
        data = vm.get_code(code_pos, size)
        vm.extend_memory(mem_pos, size)
        vm.memory_store(mem_pos, size, data)
      end

      def_op :GASPRICE, 0x3a, 0, 1 do |vm|
        vm.push vm.instruction.price
      end

      def_op :EXTCODESIZE, 0x3b, 0, 1 do |vm|
        address = vm.pop(Address)
        code_size = vm.get_account_code(address).size
        vm.push code_size
      end

      def_op :EXTCODECOPY, 0x3c, 4, 0 do |vm|
        address = vm.pop(Address)
        mem_pos, data_pos, size = vm.pop_list(3, Integer)

        code = vm.get_account_code(address)
        data_end_pos = data_pos + size - 1
        data = if data_pos >= code.size
                 ''.b
               elsif data_end_pos >= code.size
                 code[data_pos..-1]
               else
                 code[data_pos..data_end_pos]
               end
        vm.extend_memory(mem_pos, size)
        vm.memory_store(mem_pos, size, data)
      end

      RETURNDATASIZE = 0x3d
      RETURNDATACOPY = 0x3e

      # 40s: block information
      def_op :BLOCKHASH, 0x40, 1, 1 do |vm|
        height = vm.pop(Integer)
        # cause current block hash do not exists in chain
        # here we compute distance of parent height and ancestor height
        # and use parent_hash to find ancestor hash
        distance = vm.block_info.number - height - 1
        vm.push vm.state.get_ancestor_hash(vm.block_info.parent_hash, distance)
      end

      def_op :COINBASE, 0x41, 0, 1 do |vm|
        vm.push vm.block_info.coinbase
      end

      def_op :TIMESTAMP, 0x42, 0, 1 do |vm|
        vm.push vm.block_info.timestamp
      end

      def_op :NUMBER, 0x43, 0, 1 do |vm|
        vm.push vm.block_info.number
      end

      def_op :DIFFICULTY, 0x44, 0, 1 do |vm|
        vm.push vm.block_info.difficulty
      end

      def_op :GASLIMIT, 0x45, 0, 1 do |vm|
        vm.push vm.block_info.gas_limit
      end

      # 50s: Stack, Memory, Storage and Flow Operations
      def_op :POP, 0x50, 1, 0 do |vm|
        vm.pop
      end

      def_op :MLOAD, 0x51, 1, 1 do |vm|
        index = vm.pop(Integer)
        vm.extend_memory(index, 32)
        vm.push vm.memory_fetch(index, 32)
      end

      def_op :MSTORE, 0x52, 2, 0 do |vm|
        index = vm.pop(Integer)
        data = vm.pop
        vm.extend_memory(index, 32)
        vm.memory_store(index, 32, data)
      end

      def_op :MSTORE8, 0x53, 2, 0 do |vm|
        index = vm.pop(Integer)
        data = vm.pop(Integer)
        vm.extend_memory(index, 8)
        vm.memory_store(index, 1, data % 256)
      end

      def_op :SLOAD, 0x54, 1, 1 do |vm|
        key = vm.pop(Integer)
        vm.push vm.fetch(vm.instruction.address, key)
      end

      def_op :SSTORE, 0x55, 2, 0 do |vm|
        key = vm.pop(Integer)
        value = vm.pop(Integer)

        vm.store(vm.instruction.address, key, value)
      end

      def_op :JUMP, 0x56, 1, 0 do |vm|
        pc = vm.pop(Integer)
        vm.jump_to(pc)
      end

      def_op :JUMPI, 0x57, 2, 0 do |vm|
        dest, cond = vm.pop_list(2, Integer)
        if cond != 0
          vm.jump_to(dest)
        else
          vm.jump_to(vm.pc + 1)
        end
      end

      def_op :PC, 0x58, 0, 1 do |vm|
        vm.push vm.pc
      end

      def_op :MSIZE, 0x59, 0, 1 do |vm|
        vm.push 32 * vm.memory_item
      end

      def_op :GAS, 0x5a, 0, 1 do |vm|
        vm.push vm.remain_gas
      end

      def_op :JUMPDEST, 0x5b, 0, 0

      # 60s & 70s: Push Operations
      # PUSH1 - PUSH32
      (1..32).each do |i|
        name = "PUSH#{i}"
        def_op name, 0x60 + i - 1, 0, 1, &(proc do |byte_size|
          proc do |vm|
            vm.push vm.get_code(vm.pc + 1, byte_size)
          end
        end.call(i))
      end

      # 80s: Duplication Operations
      # DUP1 - DUP16
      (1..16).each do |i|
        name = "DUP#{i}"
        def_op name, 0x80 + i - 1, i, i + 1, &(proc do |i|
          proc do |vm|
            vm.push vm.stack[i - 1].dup
          end
        end.call(i))
      end

      # 90s: Exchange Operations
      # SWAP1 - SWAP16
      (1..16).each do |i|
        name = "SWAP#{i}"
        def_op name, 0x90 + i - 1, i + 1, i + 1, &(proc do |i|
          proc do |vm|
            vm.stack[0], vm.stack[i] = vm.stack[i], vm.stack[0]
          end
        end.call(i))
      end

      # a0s: Logging Operations
      # LOG0 - LOG4
      (0..4).each do |i|
        name = "LOG#{i}"
        def_op name, 0xa0 + i, i + 2, 0, &(proc do |i|
          proc do |vm|
            pos, size = vm.pop_list(2, Integer)
            log_data = vm.memory_fetch(pos, size)
            vm.extend_memory(pos, size)
            topics = vm.pop_list(i, Integer)
            vm.add_log_entry(topics, log_data)
          end
        end.call(i))
      end

      # f0s: System operations
      def_op :CREATE, 0xf0, 3, 1 do |vm|
        value = vm.pop(Integer)
        mem_pos, size = vm.pop_list(2, Integer)

        init = vm.memory_fetch(mem_pos, size)
        vm.extend_memory(mem_pos, size)

        contract_address, _ = vm.create_contract(value: value, init: init, touch_nonce: false)
        vm.push contract_address
      end

      def_op :CALL, 0xf1, 7, 1 do |vm|
        gas, to, value, data, output_mem_pos, output_mem_size = extract_call_argument(vm)
        call_message(vm: vm, sender: vm.instruction.address, value: value, gas: gas, to: to,
                     data: data, code_address: to, output_mem_pos: output_mem_pos, output_mem_size: output_mem_size)
      end

      def_op :CALLCODE, 0xf2, 7, 1 do |vm|
        gas, to, value, data, output_mem_pos, output_mem_size = extract_call_argument(vm)
        call_message(vm: vm, sender: vm.instruction.address, value: value, gas: gas, to: vm.instruction.address,
                     data: data, code_address: to, output_mem_pos: output_mem_pos, output_mem_size: output_mem_size)
      end

      def_op :RETURN, 0xf3, 2, 0 do |vm|
        index, size = vm.pop_list(2, Integer)
        vm.extend_memory(index, size)
        vm.set_output vm.memory_fetch(index, size)
      end

      def_op :DELEGATECALL, -0xf4, 6, 1 do |vm|
        gas, to, _value, data, output_mem_pos, output_mem_size = extract_call_argument(vm, delegate_call: true)
        call_message(vm: vm, sender: vm.instruction.sender, value: vm.instruction.value, gas: gas,
                     to: vm.instruction.address, data: data, code_address: to,
                     output_mem_pos: output_mem_pos, output_mem_size: output_mem_size)
      end

      STATICCALL = 0xfa

      # TODO REVERT need to be implement in forks
      def_op :REVERT, -0xfd, 2, 0 do |vm|
        index, size = vm.pop_list(2, Integer)
        vm.output = vm.memory_fetch(index, size)
        vm.extend_memory(index, size)
      end

      def_op :INVALID, 0xfe, 0, 0 do |vm|
        raise 'should not invoke INVALID'
      end

      def_op :SELFDESTRUCT, 0xff, 1, 0 do |vm|
        refund_address = vm.pop(Address)
        contract_account = vm.find_account vm.instruction.address

        vm.state.add_balance(refund_address, contract_account.balance)
        vm.state.set_balance(vm.instruction.address, 0)

        # register changed accounts
        vm.add_refund_account(refund_address)
        vm.add_suicide_account(vm.instruction.address)
      end

      private

      def self.extract_call_argument(vm, delegate_call: false)
        gas = vm.pop(Integer)
        to = vm.pop(Address)
        value = delegate_call ? 0 : vm.pop(Integer)
        input_mem_pos, input_size = vm.pop_list(2, Integer)
        vm.extend_memory(input_mem_pos, input_size)
        data = vm.memory_fetch(input_mem_pos, input_size)
        output_mem_pos, output_mem_size = vm.pop_list(2, Integer)
        [gas, to, value, data, output_mem_pos, output_mem_size]
      end

      def self.call_message(vm:, gas:, sender:, value:, data:, to:, code_address: to, output_mem_pos:, output_mem_size:)
        context = vm.execution_context
        child_gas_limit, child_gas_fee = context.fork_schema.gas_of_call(vm: vm,
                                                                         gas: gas, to: to, value: value)
        context.consume_gas(child_gas_fee)
        child_context = context.child_context(gas_limit: child_gas_limit)
        status, output = vm.call_message(sender: sender, value: value, data: data, target: to,
                                         code_address: code_address, context: child_context, touch_nonce: false)

        context.return_gas(child_context.remain_gas)
        output_size = [output_mem_size, output.size].min
        vm.extend_memory(output_mem_pos, output_size)
        vm.memory_store(output_mem_pos, output_size, output)
        vm.push status
      end

    end
  end
end
