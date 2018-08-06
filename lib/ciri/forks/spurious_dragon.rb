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
require_relative 'tangerine_whistle'
require_relative 'spurious_dragon/transaction'
require_relative 'spurious_dragon/cost'

module Ciri
  module Forks
    # https://github.com/ethereum/EIPs/blob/master/EIPS/eip-607.md
    module SpuriousDragon
      class Schema < Forks::TangerineWhistle::Schema

        CONTRACT_CODE_SIZE_LIMIT = 2 ** 14 + 2 ** 13

        def initialize
          super
          @cost = Cost.new
        end

        def transaction_class
          Transaction
        end

        def contract_code_size_limit
          CONTRACT_CODE_SIZE_LIMIT
        end

        def contract_init_nonce
          1
        end

        def clean_empty_accounts?
          true
        end

      end
    end
  end
end
