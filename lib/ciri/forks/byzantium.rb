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
require_relative 'spurious_dragon'
require_relative 'byzantium/opcodes'
require 'ciri/types/receipt'
require 'ciri/utils'
require 'ciri/rlp'

module Ciri
  module Forks
    # https://github.com/ethereum/EIPs/blob/181867ae830df5419eb9982d2a24797b2dcad28f/EIPS/eip-609.md
    module Byzantium
      class Schema < Forks::SpuriousDragon::Schema

        BLOCK_REWARD = 3 * 10.pow(18) # 3 ether

        TRANSACTION_STATUS_FAILURE = ''.b
        TRANSACTION_STATUS_SUCCESS = "\x01".b

        BLANK_OMMERS_HASH = Utils.keccak(RLP.encode([])).freeze

        def calculate_difficulty(header, parent_header)
          # https://github.com/ethereum/EIPs/blob/984cf5de90bbf5fbe7e49be227b0c2f9567e661e/EIPS/eip-100.md
          y = parent_header.ommers_hash == BLANK_OMMERS_HASH ? 1 : 2
          difficulty_time_factor = [y - (header.timestamp - parent_header.timestamp) / 9, -99].max
          x = parent_header.difficulty / 2048

          # difficulty bomb
          height = [(header.number - 3000000), 0].max
          height_factor = 2 ** (height / 100000 - 2)

          difficulty = (parent_header.difficulty + x * difficulty_time_factor + height_factor).to_i
          [header.difficulty, difficulty].max
        end

        def get_operation(op)
          OPCODES[op]
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

        # https://github.com/ethereum/EIPs/blob/181867ae830df5419eb9982d2a24797b2dcad28f/EIPS/eip-658.md
        def make_receipt(execution_result:, gas_used:)
          status = execution_result.status == 1 ? TRANSACTION_STATUS_SUCCESS : TRANSACTION_STATUS_FAILURE
          Types::Receipt.new(state_root: status, gas_used: gas_used, logs: execution_result.logs)
        end

      end
    end
  end
end
