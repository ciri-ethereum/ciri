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


require 'ciri/evm/op'
require 'ciri/forks/frontier/cost'

module Ciri
  module Forks
    module TangerineWhistle

      class Cost < Frontier::Cost

        include Ciri::EVM::OP

        #   fee schedule, start with G
        G_EXTCODE = 700
        G_BALANCE = 400
        G_SLOAD = 200
        R_SELFDESTRUCT = 24000
        G_SELFDESTRUCT = 5000
        G_CALL = 700
        G_NEWACCOUNT = 25000
        G_COPY = 3
        G_CALLSTIPEND = 2300
        G_CALLVALUE = 9000
        W_EXTCODE = [EXTCODESIZE]

        # C(σ,μ,I)
        # calculate cost of current operation
        def gas_of_operation(vm)
          ms = vm.machine_state
          instruction = vm.instruction
          w = instruction.get_op(vm.pc)

          if w == EXTCODECOPY
            G_EXTCODE + G_COPY * Utils.ceil_div(ms.get_stack(3, Integer), 32)
          elsif w == CALL || w == CALLCODE || w == DELEGATECALL
            G_CALL
          elsif w == SELFDESTRUCT
            cost_of_self_destruct(vm)
          elsif w == SLOAD
            G_SLOAD
          elsif W_EXTCODE.include? w
            G_EXTCODE
          elsif w == BALANCE
            G_BALANCE
          else
            super
          end
        end

        def gas_of_call(vm:, gas:, to:, value:)
          account_exists = vm.account_exist?(to)
          transfer_gas_fee = value > 0 ? G_CALLVALUE : 0
          create_gas_fee = !account_exists ? G_NEWACCOUNT : 0
          extra_gas = transfer_gas_fee + create_gas_fee

          gas = [gas, max_child_gas_eip150(vm.remain_gas - extra_gas)].min
          total_fee = gas + extra_gas
          child_gas_limit = gas + (value > 0 ? G_CALLSTIPEND : 0)
          [child_gas_limit, total_fee]
        end

        private

        def max_child_gas_eip150(gas)
          gas - (gas / 64)
        end

        def cost_of_self_destruct(vm)
          balance_is_zero = vm.find_account(vm.instruction.address).balance == 0
          refund_address = vm.get_stack(0, Address)
          if vm.account_exist?(refund_address) || balance_is_zero
            G_SELFDESTRUCT
          else
            G_SELFDESTRUCT + G_NEWACCOUNT
          end
        end

      end

    end
  end
end
