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
  module Forks
    module Frontier

      module Cost

        include Ciri::EVM::OP

        #   fee schedule, start with G
        G_ZERO = 0
        G_BASE = 2
        G_VERYLOW = 3
        G_LOW = 5
        G_MID = 8
        G_HIGH = 10
        G_EXTCODE = 20
        G_BALANCE = 20
        G_SLOAD = 50
        G_JUMPDEST = 1
        G_SSET = 20000
        G_RESET = 5000
        R_SCLEAR = 15000
        R_SELFDESTRUCT = 24000
        G_SELFDESTRUCT = 0
        G_CREATE = 32000
        G_CODEDEPOSIT = 200
        G_CALL = 40
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
        W_ZERO = [STOP, RETURN, REVERT]
        W_BASE = [ADDRESS, ORIGIN, CALLER, CALLVALUE, CALLDATASIZE, CODESIZE, GASPRICE,
                  COINBASE, TIMESTAMP, NUMBER, DIFFICULTY, GASLIMIT, RETURNDATASIZE,
                  POP, PC, MSIZE, GAS]
        W_VERYLOW = [ADD, SUB, NOT, LT, GT, SLT, SGT, EQ, ISZERO, AND, OR,
                     XOR, BYTE, CALLDATALOAD, MLOAD, MSTORE, MSTORE8,
                     *(1..32).map {|i| EVM::OP.get(PUSH1 + i - 1).code}, # push1 - push32
                     *(1..16).map {|i| EVM::OP.get(DUP1 + i - 1).code}, # dup1 - dup16
                     *(1..16).map {|i| EVM::OP.get(SWAP1 + i - 1).code}] # swap1 - swap16
        W_LOW = [MUL, DIV, SDIV, MOD, SMOD, SIGNEXTEND]
        W_MID = [ADDMOD, MULMOD, JUMP]
        W_HIGH = [JUMPI]
        W_EXTCODE = [EXTCODESIZE]


        class << self
          include Ciri::EVM::OP

          # C(σ,μ,I)
          # calculate cost of current operation
          def cost_of_operation(vm)
            ms = vm.machine_state
            instruction = vm.instruction
            w = instruction.get_op(vm.pc)
            if w == SSTORE
              cost_of_sstore(vm)
            elsif w == EXP && ms.get_stack(1, Integer) == 0
              G_EXP
            elsif w == EXP && (x = ms.get_stack(1, Integer)) > 0
              G_EXP + G_EXPBYTE * Utils.ceil_div(x.bit_length, 8)
            elsif w == CALLDATACOPY || w == CODECOPY || w == RETURNDATACOPY
              G_VERYLOW + G_COPY * Utils.ceil_div(ms.get_stack(2, Integer), 32)
            elsif w == EXTCODECOPY
              G_EXTCODE + G_COPY * Utils.ceil_div(ms.get_stack(3, Integer), 32)
            elsif (LOG0..LOG4).include? w
              G_LOG + G_LOGDATA * ms.get_stack(1, Integer) + (w - LOG0) * G_TOPIC
            elsif w == CALL || w == CALLCODE || w == DELEGATECALL
              G_CALL
            elsif w == SELFDESTRUCT
              cost_of_self_destruct(vm)
            elsif w == CREATE
              G_CREATE
            elsif w == SHA3
              G_SHA3 + G_SHA3WORD * Utils.ceil_div(ms.get_stack(1, Integer), 32)
            elsif w == JUMPDEST
              G_JUMPDEST
            elsif w == SLOAD
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
            elsif w == BALANCE
              G_BALANCE
            elsif w == BLOCKHASH
              G_BLOCKHASH
            else
              raise "can't compute cost for unknown op #{w}"
            end
          end

          def cost_of_memory(i)
            G_MEMORY * i + (i ** 2) / 512
          end

          def intrinsic_gas_of_transaction(t)
            gas = (t.data.each_byte || '').reduce(0) {|sum, i| sum + (i.zero? ? G_TXDATAZERO : G_TXDATANONZERO)}
            # gas + (t.to.empty? ? G_TXCREATE : 0) + G_TRANSACTION
            gas + G_TRANSACTION
          end

          def gas_of_call(vm:, gas:, to:, value:)
            # TODO handle gas calculation for all categories calls
            account_exists = vm.account_exist?(to)
            transfer_gas_fee = value > 0 ? G_CALLVALUE : 0
            create_gas_fee = !account_exists ? G_NEWACCOUNT : 0
            extra_gas = transfer_gas_fee + create_gas_fee

            total_fee = gas + extra_gas
            child_gas_limit = gas + (value > 0 ? G_CALLSTIPEND : 0)
            [child_gas_limit, total_fee]
          end

          private

          def cost_of_self_destruct(vm)
            G_SELFDESTRUCT
          end

          def cost_of_sstore(vm)
            ms = vm.machine_state
            instruction = vm.instruction

            key = ms.get_stack(0, Integer)
            value = ms.get_stack(1, Integer)

            current_is_empty = vm.fetch(instruction.address, key).zero?
            value_is_empty = value.nil? || value.zero?

            gas_cost = if current_is_empty && !value_is_empty
                         G_SSET
                       else
                         G_RESET
                       end
            gas_refund = if !current_is_empty && value_is_empty
                           R_SCLEAR
                         else
                           0
                         end

            [gas_cost, gas_refund]
          end

        end
      end

    end
  end
end
