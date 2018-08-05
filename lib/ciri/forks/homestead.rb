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

        include Forks::Frontier::Cost

        def initialize(support_dao_fork:)
          @support_dao_fork = support_dao_fork
        end

        def intrinsic_gas_of_transaction(t)
          gas = (t.data.each_byte || '').reduce(0) {|sum, i| sum + (i.zero? ? G_TXDATAZERO : G_TXDATANONZERO)}
          gas + (t.to.empty? ? G_TXCREATE : 0) + G_TRANSACTION
        end

        # chain difficulty method
        # https://github.com/ethereum/EIPs/blob/984cf5de90bbf5fbe7e49be227b0c2f9567e661e/EIPS/eip-2.md
        def difficulty_time_factor(header, parent_header)
          [1 - (header.timestamp - parent_header.timestamp) / 10, -99].max
        end

        def transaction_class
          Transaction
        end

        def get_operation(op)
          OPCODES[op]
        end

      end
    end
  end
end
