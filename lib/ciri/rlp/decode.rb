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

module Ciri
  module RLP
    module Decode

      # Decode input from rlp encoding, only produce string or array
      #
      # Examples:
      #
      #   Ciri::RLP.decode(input)
      #
      def decode(input, type = Raw)
        decode_with_type(input, type)
      end

      # Use this method after RLP.decode, decode values from string or array to specific types
      # see Ciri::RLP::Serializable::TYPES for supported types
      #
      # Examples:
      #
      #   item = Ciri::RLP.decode(encoded_text)
      #   decode_with_type(item, Integer)
      #
      def decode_with_type(s, type)
        s = StringIO.new(s) if s.is_a?(String)
        if type == Integer
          item = s.read(1)
          if item.nil?
            raise InvalidValueError.new "invalid bool value nil"
          elsif item == "\x80".b || item.empty?
            0
          elsif item.ord < 0x80
            item.ord
          else
            size = item[0].ord - 0x80
            Ciri::Utils.big_endian_decode(s.read(size))
          end
        elsif type == Bool
          item = s.read(1)
          if item == Bool::ENCODED_TRUE
            true
          elsif item == Bool::ENCODED_FALSE
            false
          else
            raise InvalidValueError.new "invalid bool value #{item}"
          end
        elsif type.is_a?(Class) && type < Serializable
          type.rlp_decode!(s)
        elsif type.is_a?(Array)
          decode_list(s) do |list, s2|
            until s2.eof?
              list << decode_with_type(s2, type[0])
            end
          end
        elsif type == Raw
          decode_stream(s)
        else
          raise RLP::InvalidValueError.new "unknown type #{type}"
        end
      rescue
        STDERR.puts "when decoding #{s} into #{type}"
        raise
      end

      protected

      def decode_list(s, first_char = nil, &decoder)
        s = StringIO.new(s) if s.is_a?(String)
        c = first_char || s.read(1)
        list = []

        sub_s = case c.ord
                when 0xc0..0xf7
                  length = c.ord - 0xc0
                  s.read(length)
                when 0xf8..0xff
                  length_binary = s.read(c.ord - 0xf7)
                  length = int_from_binary(length_binary)
                  s.read(length)
                else
                  raise InvalidValueError.new("invalid char #{c}")
                end

        decoder.call(list, StringIO.new(sub_s))
        list
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
        else
          decode_list(s, c) do |list, s2|
            until s2.eof?
              list << decode_stream(s2)
            end
          end
        end
      end

      def int_from_binary(input)
        Ciri::Utils.big_endian_decode(input)
      end

    end
  end
end