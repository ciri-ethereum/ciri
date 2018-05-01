require_relative 'rlp/decode'
require_relative 'rlp/encode'
require_relative 'rlp/serializable'

module Eth
  module RLP
    class InvalidValueError < StandardError
    end

    class << self

      # Decode input from rlp encoding, only produce string or array
      #
      # Examples:
      #
      #   Eth::RLP.decode(input)
      #
      def decode(input)
        Decode.decode(input)
      end

      # Encode input to rlp encoding, only allow string or array
      #
      # Examples:
      #
      #   Eth::RLP.encode("hello world")
      #
      def encode(input)
        Encode.encode(input)
      end

      # Use this method before RLP.encode, this method encode ruby objects to rlp friendly format, string or array.
      # see Eth::RLP::Serializable::TYPES for supported types
      #
      # Examples:
      #
      #   item = Eth::RLP.encode_with_type(number, :int, zero: "\x00".b)
      #   encoded_text = Eth::RLP.encode(item)
      #
      def encode_with_type(item, type, zero: '')
        Serializable.encode_with_type(item, type, zero: zero)
      end

      # Use this method after RLP.decode, decode values from string or array to specific types
      # see Eth::RLP::Serializable::TYPES for supported types
      #
      # Examples:
      #
      #   item = Eth::RLP.decode(encoded_text)
      #   number = Eth::RLP.decode_with_type(item, :int)
      #
      def decode_with_type(item, type)
        Serializable.decode_with_type(item, type)
      end

    end
  end
end