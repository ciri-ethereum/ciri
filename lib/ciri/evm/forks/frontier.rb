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


require 'ciri/evm/op'

module Ciri
  module EVM
    module Forks
      module Frontier

        class << self
          def new_fork_config
            ForkConfig.new(
              cost_of_operation: proc {|state, machine_state, instruction|
                Cost.cost_of_operation state, machine_state, instruction},
              cost_of_memory: proc {|i| Cost.cost_of_memory i},
            )
          end
        end

        module Cost
          include Ciri::EVM
          #   fee schedule, start with G
          G_ZERO = 0
          G_BASE = 2
          G_VERYLOW = 3
          G_LOW = 5
          G_MID = 8
          G_HIGH = 10
          G_EXTCODE = 700
          G_BALANCE = 400
          G_SLOAD = 50
          G_JUMPDEST = 1
          G_SSET = 20000
          G_RESET = 5000
          R_SCLEAR = 15000
          R_SELFDESTRUCT = 24000
          G_SELFDESTRUCT = 5000
          G_CREATE = 32000
          G_CODEDEPOSIT = 200
          G_CALL = 700
          G_CALLVALUE = 9000
          G_CALLSTIPEND = 2300
          G_NEWACCOUNT = 25000
          G_EXP = 10
          G_EXPBYTE = 10
          G_MEMORY = 3
          G_TXCREATE = 32000
          G_TXDATAZERO = 4
          G_TXDATANONZERO = 68
          G_TRANSACTION = 21000
          G_LOG = 375
          G_LOGDATA = 8
          G_TOPIC = 375
          G_SHA3 = 30
          G_SHA3WORD = 6
          G_COPY = 3
          G_BLOCKHASH = 20
          G_QUADDIVISOR = 100

          # operation code by group, for later calculation
          W_ZERO = [OP::STOP, OP::RETURN, OP::REVERT]
          W_BASE = [OP::ADDRESS, OP::ORIGIN, OP::CALLER, OP::CALLVALUE, OP::CALLDATASIZE, OP::CODESIZE, OP::GASPRICE,
                    OP::COINBASE, OP::TIMESTAMP, OP::NUMBER, OP::DIFFICULTY, OP::GASLIMIT, OP::RETURNDATASIZE,
                    OP::POP, OP::PC, OP::MSIZE, OP::GAS]
          W_VERYLOW = [OP::ADD, OP::SUB, OP::NOT, OP::LT, OP::GT, OP::SLT, OP::SGT, OP::EQ, OP::ISZERO, OP::AND, OP::OR,
                       OP::XOR, OP::BYTE, OP::CALLDATALOAD, OP::MLOAD, OP::MSTORE, OP::MSTORE8,
                       *(1..32).map {|i| OP.get(OP::PUSH1 + i - 1).code}, # push1 - push32
                       *(1..16).map {|i| OP.get(OP::DUP1 + i - 1).code}, # dup1 - dup16
                       *(1..16).map {|i| OP.get(OP::SWAP1 + i - 1).code}] # swap1 - swap16
          W_LOW = [OP::MUL, OP::DIV, OP::SDIV, OP::MOD, OP::SMOD, OP::SIGNEXTEND]
          W_MID = [OP::ADDMOD, OP::MULMOD, OP::JUMP]
          W_HIGH = [OP::JUMPI]
          W_EXTCODE = [OP::EXTCODESIZE]


          class << self
            # C(σ,μ,I)
            # calculate cost of current operation
            def cost_of_operation(state, ms, instruction)
              w = instruction.get_op(ms.pc)
              if w == OP::SSTORE
                cost_of_sstore(state, ms, instruction)
              elsif w == OP::EXP && ms.get_stack(1, Integer) == 0
                G_EXP
              elsif w == OP::EXP && (x = ms.get_stack(1, Integer)) > 0
                G_EXP + G_EXPBYTE * Utils.ceil_div(x.bit_length, 8)
              elsif w == OP::CALLDATACOPY || w == OP::CODECOPY || w == OP::RETURNDATACOPY
                G_VERYLOW + G_COPY * Utils.ceil_div(ms.get_stack(2, Integer), 32)
              elsif w == OP::EXTCODECOPY
                G_EXTCODE + G_COPY * Utils.ceil_div(ms.get_stack(3, Integer), 32)
              elsif (OP::LOG0..OP::LOG4).include? w
                G_LOG + G_LOGDATA * ms.get_stack(1, Integer) + (w - OP::LOG0) * G_TOPIC
              elsif w == OP::CALL || w == OP::CALLCODE || w == OP::DELEGATECALL
                cost_of_call(state, ms)
              elsif w == OP::SELFDESTRUCT
                cost_of_self_destruct(state, ms)
              elsif w == OP::CREATE
                G_CREATE
              elsif w == OP::SHA3
                G_SHA3 + G_SHA3WORD * Utils.ceil_div(ms.get_stack(1, Integer), 32)
              elsif w == OP::JUMPDEST
                G_JUMPDEST
              elsif w == OP::SLOAD
                G_SLOAD
              elsif W_ZERO.include? w
                G_ZERO
              elsif W_BASE.include? w
                G_BASE
              elsif W_VERYLOW.include? w
                G_VERYLOW
              elsif W_LOW.include? w
                G_LOW
              elsif W_MID.include? w
                G_MID
              elsif W_HIGH.include? w
                G_HIGH
              elsif W_EXTCODE.include? w
                G_EXTCODE
              elsif w == OP::BALANCE
                G_BALANCE
              elsif w == OP::BLOCKHASH
                G_BLOCKHASH
              else
                raise "can't compute cost for unknown op #{w}"
              end
            end

            def cost_of_memory(i)
              G_MEMORY * i + (i ** 2) / 512
            end

            private

            def cost_of_self_destruct(state, ms)

            end

            def cost_of_call

            end

            def cost_of_sstore(state, ms, instruction)
              key = ms.stack[0]
              value = ms.stack[1]
              account = state[instruction.address]

              value_exists = !Ciri::Utils.blank_binary?(value)
              has_key = account && account.storage[key]

              if value_exists && !has_key
                G_SSET
              else
                G_RESET
              end
            end

          end
        end

      end
    end
  end
end