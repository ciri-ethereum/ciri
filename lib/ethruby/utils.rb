require 'digest/sha3'

module Eth
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

      def create_ec_pk(raw_pubkey:, raw_privkey: nil)
        group = OpenSSL::PKey::EC::Group.new('secp256k1')
        bn = OpenSSL::BN.new(raw_pubkey, 2)
        public_key = OpenSSL::PKey::EC::Point.new(group, bn)
        OpenSSL::PKey::EC.new('secp256k1').tap do |key|
          key.public_key = public_key
          key.private_key = OpenSSL::BN.new(raw_privkey, 2) if raw_privkey
        end
      end
    end

  end
end