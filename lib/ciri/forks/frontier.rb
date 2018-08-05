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


require_relative 'base'
require_relative 'frontier/cost'
require_relative 'frontier/transaction'
require_relative 'frontier/opcodes'
require 'ciri/core_ext'
require 'ciri/evm/precompile_contract'

using Ciri::CoreExt

module Ciri
  module Forks
    module Frontier
      class Schema < Base

        BLOCK_REWARD = 5 * 10.pow(18) # 5 ether

        # gas methods
        def gas_of_operation(vm)
          Cost.cost_of_operation vm
        end

        def gas_of_memory(word_count)
          Cost.cost_of_memory word_count
        end

        def gas_of_call(vm:, gas:, to:, value:)
          Cost.gas_of_call(vm: vm, gas: gas, to: to, value: value)
        end

        def intrinsic_gas_of_transaction(transaction)
          Cost.intrinsic_gas_of_transaction transaction
        end

        def calculate_deposit_code_gas(code_bytes)
          Cost::G_CODEDEPOSIT * (code_bytes || ''.b).size
        end

        def calculate_refund_gas(vm)
          vm.execution_context.all_suicide_accounts.size * Cost::R_SELFDESTRUCT
        end

        def mining_rewards_of_block(block)
          rewards = Hash.new(0)
          # reward miner
          rewards[block.header.beneficiary] += ((1 + block.ommers.count.to_f / 32) * BLOCK_REWARD).to_i

          # reward ommer(uncle) block miners
          block.ommers.each do |ommer|
            rewards[ommer.beneficiary] += ((1 + (ommer.number - block.header.number).to_f / 8) * BLOCK_REWARD).to_i
          end
          rewards
        end

        # chain difficulty method
        def difficulty_time_factor(header, parent_header)
          (header.timestamp - parent_header.timestamp) < 13 ? 1 : -1
        end

        def difficulty_virtual_height(height)
          height
        end

        PRECOMPILE_CONTRACTS = {
            "\x01".pad_zero(20).b => EVM::PrecompileContract::ECRecover.new,
            "\x02".pad_zero(20).b => EVM::PrecompileContract::SHA256.new,
            "\x03".pad_zero(20).b => EVM::PrecompileContract::RIPEMD160.new,
            "\x04".pad_zero(20).b => EVM::PrecompileContract::Identity.new,
        }.freeze

        # EVM op code and contract
        def find_precompile_contract(address)
          PRECOMPILE_CONTRACTS[address.to_s]
        end

        def transaction_class
          Transaction
        end

        def get_operation(op)
          OPCODES[op]
        end

        def exception_on_deposit_code_gas_not_enough
          false
        end

      end
    end
  end
end
