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


require_relative 'base'
require_relative 'frontier/cost'
require_relative 'frontier/transaction'
require_relative 'frontier/opcodes'
require 'ciri/types/receipt'
require 'ciri/core_ext'
require 'ciri/evm/precompile_contract'
require 'forwardable'

using Ciri::CoreExt

module Ciri
  module Forks
    module Frontier
      class Schema < Base

        extend Forwardable

        BLOCK_REWARD = 5 * 10.pow(18) # 5 ether

        def initialize
          @cost = Cost.new
        end

        def_delegators :@cost, :gas_of_operation, :gas_of_memory, :gas_of_call, :intrinsic_gas_of_transaction

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

        def calculate_difficulty(header, parent_header)
          difficulty_time_factor = (header.timestamp - parent_header.timestamp) < 13 ? 1 : -1
          x = parent_header.difficulty / 2048

          # difficulty bomb
          height = header.number
          height_factor = 2 ** (height / 100000 - 2)

          difficulty = (parent_header.difficulty + x * difficulty_time_factor + height_factor).to_i
          [header.difficulty, difficulty].max
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

        def contract_code_size_limit
          Float::INFINITY
        end

        def contract_init_nonce
          0
        end

        def clean_empty_accounts?
          false
        end

        def make_receipt(execution_result:, gas_used:)
          Types::Receipt.new(state_root: execution_result.state_root, gas_used: gas_used, logs: execution_result.logs)
        end

      end
    end
  end
end
