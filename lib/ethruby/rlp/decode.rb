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


require 'stringio'

module ETH
  module RLP
    module Decode

      class InvalidInput < StandardError
      end

      class << self
        def decode(input)
          s = StringIO.new(input).binmode
          decode_stream(s)
        end

        private
        def decode_stream(s)
          c = s.read(1)
          case c.ord
            when 0x00..0x7f
              c
            when 0x80..0xb7
              length = c.ord - 0x80
              s.read(length)
            when 0xb8..0xbf
              length_binary = s.read(c.ord - 0xb7)
              length = int_from_binary(length_binary)
              s.read(length)
            when 0xc0..0xf7
              length = c.ord - 0xc0
              s2 = StringIO.new s.read(length)
              list = []
              until s2.eof?
                list << decode_stream(s2)
              end
              list
            when 0xf8..0xff
              length_binary = s.read(c.ord - 0xf7)
              length = int_from_binary(length_binary)
              s2 = StringIO.new s.read(length)
              list = []
              until s2.eof?
                list << decode_stream(s2)
              end
              list
            else
              raise InvalidInput.new("invalid char #{c}")
          end
        end

        def int_from_binary(input)
          ETH::Utils.big_endian_decode(input)
        end

      end
    end
  end
end