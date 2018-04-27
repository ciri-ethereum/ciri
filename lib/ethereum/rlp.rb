require 'ethereum/rlp/decode'
require 'ethereum/rlp/encode'

module Ethereum
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