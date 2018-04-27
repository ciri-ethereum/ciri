require 'digest/sha3'

module Reth
  module Utils

    class << self
      def sha3(text)
        Digest::SHA3.new(256).digest text
      end

      def big_endian_encode(n)
        if n == 0
          ''
        else
          big_endian_encode(n / 256) + (n % 256).chr
        end
      end

      def big_endian_decode(input)
        input.each_byte.reduce(0) {|s, i| s * 256 + i}
      end

      def hex_to_data(hex)
        [hex].pack("H*")
      end

      def data_to_hex(data)
        data.unpack("H*").first
      end
    end

  end
end