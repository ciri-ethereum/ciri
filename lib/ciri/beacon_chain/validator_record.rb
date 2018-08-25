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


require 'ciri/rlp'
require 'ciri/types/int'
require 'ciri/types/hash'
require 'ciri/types/bytes'
require 'ciri/types/address'
require 'forwardable'

module Ciri
  module BeaconChain

    class ValidatorRecord
      include RLP::Serializable
      include Types

      schema(
          pubkey: Int256,
          withdrawal_shard: Int16,
          withdrawal_address: Address,
          random_commitment: Hash32,
          balance: Int64,
          start_dynasty: Int64,
          end_dynasty: Int64,
      )
    end

  end
end
