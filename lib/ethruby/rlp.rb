require 'ethruby/rlp/decode'
require 'ethruby/rlp/encode'

module Eth
  module RLP
    class InvalidValueError < StandardError
    end

    class << self

      def decode(input)
        Decode.decode(input)
      end

      def encode(input)
        Encode.encode(input)
      end

      # use this method before RLP.encode
      # encode item to string or array
      def encode_with_type(item, type, zero: '')
        if type == :int
          Eth::Utils.big_endian_encode(item, zero)
        elsif type == :bool
          Eth::Utils.big_endian_encode(item ? 0x01 : 0x80)
        elsif type.is_a?(Array)
          item.map {|i| encode_with_type(i, type[0])}
        else
          item
        end
      end

      # use this method after RLP.decode
      # decode values from string or array to specific types
      def decode_with_type(item, type)
        if type == :int
          Eth::Utils.big_endian_decode(item)
        elsif type == :bool
          if item == Eth::Utils.big_endian_encode(0x01)
            true
          elsif item == Eth::Utils.big_endian_encode(0x80)
            false
          else
            raise InvalidValueError.new "invalid bool value #{item}"
          end
        elsif type.is_a?(Array)
          item.map {|i| decode_with_type(i, type[0])}
        else
          item
        end
      end

    end
  end
end