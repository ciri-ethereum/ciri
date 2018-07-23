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


require_relative 'base'
require_relative 'frontier/cost'

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

        def gas_of_call(context:, gas:, to:, value:)
          Cost.gas_of_call(context: context, gas: gas, to: to, value: value)
        end

        def intrinsic_gas_of_transaction(transaction)
          Cost.intrinsic_gas_of_transaction transaction
        end

        def calculate_deposit_code_gas(code_bytes)
          Cost::G_CODEDEPOSIT * (code_bytes || ''.b).size
        end

        def calculate_refund_gas(vm)
          vm.sub_state.suicide_accounts.size * Cost::R_SELFDESTRUCT
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

      end
    end
  end
end
