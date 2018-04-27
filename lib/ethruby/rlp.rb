require 'ethruby/rlp/decode'
require 'ethruby/rlp/encode'

module Eth
  module RLP
    class << self

      def decode(input)
        Decode.decode(input)
      end

      def encode(input)
        Encode.encode(input)
      end

    end
  end
end