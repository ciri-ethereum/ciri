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


module Ciri
  class EVM

    # Block Info
    BlockInfo = Struct.new(:coinbase, :difficulty, :gas_limit, :number, :timestamp, :block_hash, :parent_hash,
                           keyword_init: true) do

      def self.from_header(header)
        BlockInfo.new(
          coinbase: header.beneficiary,
          difficulty: header.difficulty,
          gas_limit: header.gas_limit,
          number: header.number,
          timestamp: header.timestamp,
          parent_hash: header.parent_hash,
          block_hash: header.get_hash,
        )
      end
    end

  end
end
