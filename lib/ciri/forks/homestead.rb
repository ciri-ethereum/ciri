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
require_relative 'frontier'
require_relative 'homestead/transaction'
require_relative 'homestead/opcodes'

module Ciri
  module Forks
    # Homestead fork
    # https://github.com/ethereum/EIPs/blob/master/EIPS/eip-606.md
    module Homestead
      class Schema < Forks::Frontier::Schema

        include Forks::Frontier

        def initialize(support_dao_fork:)
          @support_dao_fork = support_dao_fork
          super()
        end

        def intrinsic_gas_of_transaction(t)
          gas = (t.data.each_byte || '').reduce(0) {|sum, i| sum + (i.zero? ? Cost::G_TXDATAZERO : Cost::G_TXDATANONZERO)}
          gas + (t.to.empty? ? Cost::G_TXCREATE : 0) + Cost::G_TRANSACTION
        end

        def calculate_difficulty(header, parent_header)
          # https://github.com/ethereum/EIPs/blob/984cf5de90bbf5fbe7e49be227b0c2f9567e661e/EIPS/eip-2.md
          difficulty_time_factor = [1 - (header.timestamp - parent_header.timestamp) / 10, -99].max
          x = parent_header.difficulty / 2048

          # difficulty bomb
          height = header.number
          height_factor = 2 ** (height / 100000 - 2)

          difficulty = (parent_header.difficulty + x * difficulty_time_factor + height_factor).to_i
          [header.difficulty, difficulty].max
        end

        def transaction_class
          Transaction
        end

        def get_operation(op)
          OPCODES[op]
        end

        def exception_on_deposit_code_gas_not_enough
          true
        end

      end
    end
  end
end
