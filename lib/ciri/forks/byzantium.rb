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
require_relative 'homestead'

module Ciri
  module Forks
    module Byzantium
      class Schema < Forks::Frontier::Schema

        include Forks::Frontier::Cost

        # chain difficulty method
        # https://github.com/ethereum/EIPs/blob/181867ae830df5419eb9982d2a24797b2dcad28f/EIPS/eip-609.md
        # https://github.com/ethereum/EIPs/blob/984cf5de90bbf5fbe7e49be227b0c2f9567e661e/EIPS/eip-100.md
        def difficulty_time_factor(header, parent_header)
          y = header.ommers_hash == Utils::BLANK_SHA3 ? 1 : 2
          [y - (header.timestamp - parent_header.timestamp) / 9, -99].max
        end

        def difficulty_virtual_height(height)
          [(height - 3000000), 0].max
        end

      end
    end
  end
end
