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

module Ciri
  module EVM
    module OP

      OPERATIONS = {}

      Operation = Struct.new(:code, :inputs, :outputs, :handler, keyword_init: true) do
        def call(*args)
          handler.call(*args)
        end
      end

      class << self
        # register op
        # handler receive machine_state and inputs, return outputs
        def op(code, inputs, outputs, &handler)
          OPERATIONS[code] = Operation.new(code: code, inputs: inputs, outputs: outputs, handler: handler).freeze
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

      MAX_INT = 2 ** 256

      # basic operations
      STOP = op 0x00, 0, 0
      ADD = op 0x01, 2, 1 do |m, i|
        m.push((m.pop_int + m.pop_int) % MAX_INT)
      end

      MUL = op 0x02, 2, 1 do |m, v0, v1|
        v0 * v1
      end

      SUB = op 0x03, 2, 1 do |m, v0, v1|
        v0 - v1
      end

      DIV = op 0x04, 2, 1 do |m, v0, v1|
        v1.zero? ? 0 : v0 / v1
      end

      SDIV = op 0x05, 2, 1 do |m, v0, v1|
        if v1.zero?
          0
        elsif v0 == -2 ** 255 || v1 == -1
          -2 ** 255
        else
          v0 / v1
        end
      end

      MOD = op 0x06, 2, 1 do |m, v0, v1|
        v1.zero? ? 0 : v0 % v1
      end

      SMOD = op 0x07, 2, 1 do |m, v0, v1|
        v1.zero? ? 0 : v0 % v1
      end

      ADDMOD = op 0x08, 3, 1 do |m, v0, v1, v2|
        v2.zero? ? 0 : (v0 + v1) % v2
      end

      MULMOD = op 0x09, 3, 1 do |m, v0, v1, v2|
        v2.zero? ? 0 : (v0 * v1) % v2
      end

      EXP = op 0x0a, 2, 1 do |m, v0, v1|
        v0 ** v1
      end

      SIGNEXTEND = op 0x0b, 2, 1 do |m, v0, v1|
        256.times.map do |i|
          t = 256 - 8 * (v0[0] + 1)
          i <= t ? v1[t] : v1[i]
        end
      end

      LT = op 0x10, 2, 1 do |m, v0, v1|
        v0 < v1 ? 1 : 0
      end

      GT = op 0x11, 2, 1 do |m, v0, v1|
        v0 > v1 ? 1 : 0
      end

      SLT = op 0x12, 2, 1 do |m, v0, v1|
        v0 < v1 ? 1 : 0
      end

      SGT = op 0x13, 2, 1 do |m, v0, v1|
        v0 > v1 ? 1 : 0
      end

      EQ = op 0x14, 2, 1 do |m, v0, v1|
        v0 == v1 ? 1 : 0
      end

      ISZERO = op 0x15, 1, 1 do |m, v0|
        v0.zero? ? 1 : 0
      end

      AND = op 0x16, 2, 1 do |m, v0, v1|
        v0 & v1
      end

      OR = op 0x17, 2, 1 do |m, v0, v1|
        v0 | v1
      end

      XOR = op 0x18, 2, 1 do |m, v0, v1|
        v0 ^ v1
      end

      NOT = op 0x19, 1, 1 do |m, v0|
        ~v0
      end
      BYTE = op 0x1a, 2, 1 do |m, v0, v1|
        if v0 > 32
          0
        else
          (0...8).each do |i|
            v1[i + 8 * v0[0]]
          end
        end
      end

      # 20s: sha3
      SHA3 = op 0x20, 2, 1 do |m, v0, v1|
        ret = Ciri::Utils.sha3 m.memory[v0..(v0 + v1 - 1)]
        # m.active_member = m(v0, v1)
        ret
      end

      # 30s: environment operations
      ADDRESS = 0x30
      BALANCE = 0x31
      ORIGIN = 0x32
      CALLER = 0x33
      CALLVALUE = 0x34
      CALLDATALOAD = 0x35
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
      MLOAD = 0x51
      MSTORE = 0x52
      MSTORE8 = 0x53
      SLOAD = 0x54

      SSTORE = op 0x55, 2, 0 do |vm|
        key = vm.pop
        value = vm.pop
        vm.store_data(vm.instruction.address, key, value) unless value.zero? && key == "\x00".b
      end

      JUMP = 0x56
      JUMPI = 0x57
      PC = 0x58
      MSIZE = 0x59
      GAS = 0x5a
      JUMPDEST = 0x5b
      # 60s & 70s: Push Operations
      # PUSH1 - PUSH32
      (1..32).each do |i|
        const_set("PUSH#{i}", op(0x60 + i - 1, 0, 1, &proc {|byte_size|
          proc do |vm|
            vm.push vm.get_code(vm.pc + 1, byte_size)
          end
        }.call(i)))
      end
      # 80s: Duplication Operations
      # DUP1 - DUP16
      (1..16).each do |i|
        const_set("DUP#{i}", 0x80 + i - 1)
      end
      # 90s: Exchange Operations
      # SWAP1 - SWAP16
      (1..16).each do |i|
        const_set("SWAP#{i}", 0x90 + i - 1)
      end
      # a0s: Logging Operations
      # LOG0 - LOG4
      (0..4).each do |i|
        const_set("LOG#{i}", 0xa0 + i)
      end
      # f0s: System operations
      CREATE = 0xf0
      CALL = 0xf1
      CALLCODE = 0xf2
      RETURN = 0xf3
      DELEGATECALL = 0xf4
      STATICCALL = 0xfa
      REVERT = 0xfd
      SELFDESTRUCT = 0xff

    end
  end
end
