require 'reth/rlp/decode'
require 'reth/rlp/encode'

module Reth
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