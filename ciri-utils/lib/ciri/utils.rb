require "ciri/utils/version"

require 'digest/sha3'
require_relative 'utils/number'

module Ciri
  module Utils

    class << self
      include Utils::Number


      def sha3(*data)
        s = Digest::SHA3.new(256)
        data.each {|i| s.update(i)}
        s.digest
      end

      def secret_compare(s1, s2)
        s1.size == s2.size && s1.each_byte.each_with_index.map {|b, i| b ^ s2[i].ord}.reduce(0, :+) == 0
      end

      def to_bytes(hex)
        hex = hex[2..-1] if hex.start_with?('0x')
        [hex].pack("H*")
      end

      def hex_to_number(hex)
        big_endian_decode to_bytes(hex)
      end

      def to_hex(data)
        hex = data.to_s.unpack("H*").first
        '0x' + hex
      end

      def number_to_hex(number)
        to_hex big_endian_encode(number)
      end

      def create_ec_pk(raw_pubkey: nil, raw_privkey: nil)
        public_key = raw_pubkey && begin
          group = OpenSSL::PKey::EC::Group.new('secp256k1')
          bn = OpenSSL::BN.new(raw_pubkey, 2)
          OpenSSL::PKey::EC::Point.new(group, bn)
        end

        OpenSSL::PKey::EC.new('secp256k1').tap do |key|
          key.public_key = public_key if public_key
          key.private_key = OpenSSL::BN.new(raw_privkey, 2) if raw_privkey
        end
      end

      def to_underscore(str)
        str.gsub(/[A-Z]/) {|a| "_" + a.downcase}
      end

      def blank_bytes?(item)
        return true if item.is_a?(String) && item.each_byte.all?(&:zero?)
        blank?(item)
      end

      def blank?(item)
        if item.nil?
          true
        elsif item.is_a? Integer
          item.zero?
        elsif item.is_a? String
          item.empty?
        else
          false
        end
      end

      def present?(item)
        !blank?(item)
      end

    end

    BLANK_SHA3 = Utils.sha3(''.b).freeze
  end
end
