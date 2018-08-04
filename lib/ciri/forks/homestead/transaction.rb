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


require 'ciri/forks/frontier/transaction'

module Ciri
  module Forks
    module Homestead
      class Transaction < Frontier::Transaction

        def validate!
          super
          raise InvalidError.new('signature s is low') unless signature.low_s?
        end

        def validate_intrinsic_gas!
          begin
            fork_schema = Schema.new(support_dao_fork: false)
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