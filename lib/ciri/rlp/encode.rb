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

      # Encode input to rlp encoding
      #
      # Examples:
      #
      #   Ciri::RLP.encode("hello world")
      #
      def encode(input, type = nil)
        type ? encode_with_type(input, type) : encode_simple(input)
      end

      def encode_simple(input)
        if input.is_a?(Array)
          encode_list(input) {|i| encode_simple(i)}
        elsif input.is_a?(Integer)
          encode_with_type(input, Integer)
        elsif input.class.respond_to?(:rlp_encode)
          input.class.rlp_encode(input)
        else
          encode_with_type(input, Raw)
        end
      end

      # Use this method before RLP.encode, this method encode ruby objects to rlp friendly format, string or array.
      # see Ciri::RLP::Serializable::TYPES for supported types
      #
      # Examples:
      #
      #   item = Ciri::RLP.encode_with_type(number, :int, zero: "\x00".b)
      #   encoded_text = Ciri::RLP.encode(item)
      #
      def encode_with_type(item, type, zero: '')
        if type == Integer
          if item == 0
            "\x80".b
          elsif item < 0x80
            Ciri::Utils.big_endian_encode(item, zero)
          else
            buf = Ciri::Utils.big_endian_encode(item, zero)
            [0x80 + buf.size].pack("c*") + buf
          end
        elsif type == Bool
          item ? Bool::ENCODED_TRUE : Bool::ENCODED_FALSE
        elsif type.is_a?(Class) && type.respond_to?(:rlp_encode)
          type.rlp_encode(item)
        elsif type.is_a?(Array)
          if type.size == 1 # array type
            encode_list(item) {|i| encode_with_type(i, type[0])}
          else # unknown
            raise RLP::InvalidValueError.new "type size should be 1, got #{type}"
          end
        elsif type == Raw
          encode_raw(item)
        else
          raise RLP::InvalidValueError.new "unknown type #{type}"
        end
      rescue
        STDERR.puts "when encoding #{Utils.data_to_hex item.to_s} into #{type}"
        raise
      end

      protected

      def encode_raw(input)
        result = if input.is_a?(String)
                   encode_string(input)
                 elsif input.is_a?(Array)
                   encode_list(input) {|item| encode(item)}
                 else
                   raise ArgumentError.new("input must be a String or Array, #{input.inspect}")
                 end
        result.b
      end

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

      def encode_list(input, &encoder)
        input ||= [] # allow nil list
        output = encoder ? input.map {|item| encoder.call(item)}.join : input.join
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

      private

      def to_binary(n)
        Ciri::Utils.big_endian_encode(n)
      end

    end
  end
end