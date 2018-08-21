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

require 'ciri/utils'
require 'ciri/rlp'

module Ciri
  module Types

    class UInt
      class << self
        attr_reader :size

        def rlp_encode(item)
          RLP.encode new(item).to_bytes
        end

        def rlp_decode(encoded)
          Utils.big_endian_decode(RLP.decode(encoded))
        end

        def max
          @max ||= 2 ** size - 1
        end

        def min
          0
        end

        def valid?(n)
          n >= 0 && n <= max
        end
      end

      @size = 0

      def initialize(value)
        raise "can't initialize size #{self.class.size} number" if self.class.size <= 0
        @value = value
      end

      def serialized
        Utils.big_endian_encode(@value, size: bytes_size)
      end

      alias to_bytes serialized

      def bytes_size
        self.class.size
      end

      def to_i
        @value
      end
    end

    class UInt8 < UInt
      @size = 8
    end

    class UInt32 < UInt
      @size = 32
    end

    class UInt256 < UInt
      @size = 256
    end

  end
end
