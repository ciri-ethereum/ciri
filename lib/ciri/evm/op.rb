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

module Ciri
  module EVM

    # OP module include all EVM operations
    module OP

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
        vm.push a.zero? ? 1 : 0
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
        start, size = vm.pop_list(2, Integer)
        hashed = Ciri::Utils.sha3 vm.fetch_memory(start, size)
        vm.push hashed
      end

      # 30s: environment operations
      ADDRESS = 0x30
      BALANCE = 0x31
      ORIGIN = 0x32
      CALLER = 0x33
      CALLVALUE = 0x34

      def_op :CALLDATALOAD, 0x35, 1, 1 do |vm|
        start = vm.pop(Integer)
        value = vm.data[start..(start + 31)].ljust(32, "\x00".b)
        vm.push(value)
      end

      CALLDATASIZE = 0x36
      CALLDATACOPY = 0x37
      CODESIZE = 0x38
      CODECOPY = 0x39
      GASPRICE = 0x3a
      EXTCODESIZE = 0x3b
      EXTCODECOPY = 0x3c
      RETURNDATASIZE = 0x3d
      RETURNDATACOPY = 0x3e

      # 40s: block information
      BLOCKHASH = 0x40
      COINBASE = 0x41
      TIMESTAMP = 0x42
      NUMBER = 0x43
      DIFFICULTY = 0x44
      GASLIMIT = 0x45

      # 50s: Stack, Memory, Storage and Flow Operations
      POP = 0x50

      def_op :MLOAD, 0x51, 1, 1 do |vm|
        index = vm.pop(Integer)
        vm.push vm.fetch_memory(index, 32)
        vm.memory_item = [vm.memory_item, (index + 32) / 32].max
      end

      def_op :MSTORE, 0x52, 2, 0 do |vm|
        index = vm.pop(Integer)
        data = vm.pop
        vm.memory_store(index, 32, data)
        vm.memory_item = [vm.memory_item, (index + 32) / 32].max
      end

      def_op :MSTORE8, 0x53, 2, 0 do |vm|
        index = vm.pop(Integer)
        data = vm.pop(Integer)
        vm.memory_store(index, 1, data % 256)
        vm.memory_item = [vm.memory_item, (index + 32) / 32].max
      end

      def_op :SLOAD, 0x54, 1, 1 do |vm|
        key = vm.pop
        vm.push vm.fetch_data(vm.instruction.address, key)
      end

      def_op :SSTORE, 0x55, 2, 0 do |vm|
        key = vm.pop
        value = vm.pop

        value_is_blank = Ciri::Utils.blank_binary?(value)
        key_is_blank = Ciri::Utils.blank_binary?(key)

        vm.store_data(vm.instruction.address, key, value) unless value_is_blank && key_is_blank
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

      PC = 0x58
      MSIZE = 0x59
      GAS = 0x5a
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
        def_op(name, 0xa0 + i, i + 2, 0)
      end

      # f0s: System operations
      CREATE = 0xf0
      CALL = 0xf1
      CALLCODE = 0xf2

      def_op :RETURN, 0xf3, 2, 0 do |vm|
        index, size = vm.pop_list(2, Integer)
        vm.output = vm.fetch_memory(index, size)
        if size != 0 && (i = (index + size - 1) / 32) > vm.memory_item
          vm.memory_item = i
        end
      end

      DELEGATECALL = 0xf4
      STATICCALL = 0xfa
      REVERT = 0xfd
      SELFDESTRUCT = 0xff

    end
  end
end
