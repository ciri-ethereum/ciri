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


require_relative 'rlp/decode'
require_relative 'rlp/encode'
require_relative 'rlp/serializable'

module Ciri
  module RLP
    class InvalidValueError < StandardError
    end

    class << self

      # Decode input from rlp encoding, only produce string or array
      #
      # Examples:
      #
      #   Ciri::RLP.decode(input)
      #
      def decode(input, type = nil)
        output = Decode.decode(input)
        if type
          output = decode_with_type(output, type)
        end
        output
      end

      # Encode input to rlp encoding, only allow string or array
      #
      # Examples:
      #
      #   Ciri::RLP.encode("hello world")
      #
      def encode(input, type = nil)
        if type
          input = encode_with_type(input, type)
        end
        Encode.encode(input)
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
        Serializable.encode_with_type(item, type, zero: zero)
      end

      # Use this method after RLP.decode, decode values from string or array to specific types
      # see Ciri::RLP::Serializable::TYPES for supported types
      #
      # Examples:
      #
      #   item = Ciri::RLP.decode(encoded_text)
      #   number = Ciri::RLP.decode_with_type(item, :int)
      #
      def decode_with_type(item, type)
        Serializable.decode_with_type(item, type)
      end

    end
  end
end