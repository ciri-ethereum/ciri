# frozen_string_literal: true

# Copyright (c) 2018, by Jiang Jinyang. <https://justjjy.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


module Ciri
  module Utils
    module Number
      extend self

      def big_endian_encode(n, zero = '')
        if n == 0
          zero
        else
          big_endian_encode(n / 256) + (n % 256).chr
        end
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

    end
  end
end
