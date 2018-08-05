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
          refund_address = vm.get_stack(0, Address)
          if vm.account_exist?(refund_address)
            G_SELFDESTRUCT
          else
            G_SELFDESTRUCT + G_NEWACCOUNT
          end
        end

      end

    end
  end
end
