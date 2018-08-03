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
require 'ciri/utils'
require 'ciri/types/address'
require 'ciri/types/uint'

module Ciri
  class EVM

    class LogEntry
      include RLP::Serializable
      schema [{address: Types::Address}, {topics: [Types::UInt32]}, :data]

      def to_blooms
        [address.to_s, *topics.map {|t| Utils.big_endian_encode(t, size: 32)}]
      end
    end

  end
end
