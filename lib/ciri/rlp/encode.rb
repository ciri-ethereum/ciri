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
  module RLP
    module Encode

      class InputOverflow < StandardError
      end

      class << self

        def encode(input)
          result = if input.is_a?(String)
                     encode_string(input)
                   elsif input.is_a?(Array)
                     encode_list(input)
                   else
                     raise ArgumentError.new('input must be a String or Array')
                   end
          result.b
        end

        private
        def encode_string(input)
          length = input.length
          if length == 1 && input.ord < 0x80
            input
          elsif length < 56
            to_binary(0x80 + length) + input
          elsif length < 256 ** 8
            binary_length = to_binary(length)
            to_binary(0xb7 + binary_length.size) + binary_length + input
          else
            raise InputOverflow.new("input length #{input.size} is too long")
          end
        end

        def encode_list(input)
          output = input.map {|item| encode(item)}.join
          length = output.length
          if length < 56
            to_binary(0xc0 + length) + output
          elsif length < 256 ** 8
            binary_length = to_binary(length)
            to_binary(0xf7 + binary_length.size) + binary_length + output
          else
            raise InputOverflow.new("input length #{input.size} is too long")
          end
        end

        def to_binary(n)
          Ciri::Utils.big_endian_encode(n)
        end

      end
    end
  end
end