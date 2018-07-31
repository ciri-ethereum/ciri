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
  module Utils
    module Number
      extend self

      def big_endian_encode(n, zero = ''.b, size: nil)
        b = big_endian_encode_raw(n, zero)
        size.nil? ? b : b.rjust(size, "\x00".b)
      end

      def big_endian_decode(input)
        input.each_byte.reduce(0) {|s, i| s * 256 + i}
      end

      UINT_256_MAX = 2 ** 256 - 1
      UINT_256_CEILING = 2 ** 256
      UINT_255_MAX = 2 ** 255 - 1
      UINT_255_CEILING = 2 ** 255

      def unsigned_to_signed(n)
        n <= UINT_255_MAX ? n : n - UINT_256_CEILING
      end

      def signed_to_unsigned(n)
        n >= 0 ? n : n + UINT_256_CEILING
      end

      def ceil_div(n, ceil)
        size, m = n.divmod ceil
        m.zero? ? size : size + 1
      end

      private

      def big_endian_encode_raw(n, zero = ''.b)
        if n == 0
          zero
        elsif n > 0
          big_endian_encode(n / 256) + (n % 256).chr
        else
          raise ArgumentError.new("can't encode negative number #{n}")
        end
      end

    end
  end
end
