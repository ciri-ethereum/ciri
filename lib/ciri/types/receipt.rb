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
require 'ciri/bloom_filter'
require 'ciri/types/uint'
require 'ciri/types/log_entry'

module Ciri
  module Types

    class Receipt

      include RLP::Serializable

      schema(
          state_root: RLP::Bytes,
          gas_used: Integer,
          bloom: Types::UInt256,
          logs: [LogEntry],
      )

      def initialize(state_root:, gas_used:, logs:, bloom: nil)
        bloom ||= begin
          blooms = logs.reduce([]) {|list, log| list.append *log.to_blooms}
          BloomFilter.from_iterable(blooms).to_i
        end
        super(state_root: state_root, gas_used: gas_used, logs: logs, bloom: bloom)
      end

      def bloom_filter
        BloomFilter.new(bloom)
      end

    end

  end
end
