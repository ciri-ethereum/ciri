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
require 'ciri/forks/tangerine_whistle/cost'

module Ciri
  module Forks
    module SpuriousDragon

      class Cost < TangerineWhistle::Cost

        include Ciri::EVM::OP

        #   fee schedule, start with G
        G_EXP = 10
        G_EXPBYTE = 50
        R_SELFDESTRUCT = 24000
        G_SELFDESTRUCT = 5000
        G_CALL = 700
        G_NEWACCOUNT = 25000
        G_CALLSTIPEND = 2300
        G_CALLVALUE = 9000

        # C(σ,μ,I)
        # calculate cost of current operation
        def gas_of_operation(vm)
          ms = vm.machine_state
          instruction = vm.instruction
          w = instruction.get_op(vm.pc)

          if w == CALL || w == CALLCODE || w == DELEGATECALL
            G_CALL
          elsif w == SELFDESTRUCT
            cost_of_self_destruct(vm)
          elsif w == EXP && ms.get_stack(1, Integer) == 0
            G_EXP
          elsif w == EXP && (x = ms.get_stack(1, Integer)) > 0
            G_EXP + G_EXPBYTE * Utils.ceil_div(x.bit_length, 8)
          else
            super
          end
        end

        def gas_of_call(vm:, gas:, to:, value:)
          account_is_dead = vm.account_dead?(to)
          value_exists = value > 0
          transfer_gas_fee = value_exists ? G_CALLVALUE : 0
          create_gas_fee = account_is_dead && value_exists ? G_NEWACCOUNT : 0
          extra_gas = transfer_gas_fee + create_gas_fee

          gas = [gas, max_child_gas_eip150(vm.remain_gas - extra_gas)].min
          total_fee = gas + extra_gas
          child_gas_limit = gas + (value_exists ? G_CALLSTIPEND : 0)
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
