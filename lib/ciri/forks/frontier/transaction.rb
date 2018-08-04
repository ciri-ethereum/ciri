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


require 'ciri/chain/transaction'

module Ciri
  module Forks
    module Frontier
      class Transaction < Chain::Transaction

        def validate!
          validate_sender!

          raise InvalidError.new('signature rvs error') unless signature.valid?
          raise InvalidError.new('gas_price overflow') unless UInt256.valid?(gas_price)
          raise InvalidError.new('nonce overflow') unless UInt256.valid?(nonce)
          raise InvalidError.new('gas_limit overflow') unless UInt256.valid?(gas_limit)
          raise InvalidError.new('value overflow') unless UInt256.valid?(value)

          unless v >= 27 && v <= 28
            raise InvalidError.new("v can be only 27 or 28 in frontier schema, found: #{v}")
          end

          validate_intrinsic_gas!
        end

        def validate_intrinsic_gas!
          begin
            fork_schema = Schema.new
            intrinsic_gas = fork_schema.intrinsic_gas_of_transaction(self)
          rescue StandardError
            raise InvalidError.new 'intrinsic gas calculation error'
          end
          raise InvalidError.new 'intrinsic gas not enough' unless intrinsic_gas <= gas_limit
        end

      end
    end
  end
end