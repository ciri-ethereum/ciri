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


require 'digest/sha3'

module Ciri
  module Utils

    class << self
      def sha3(*data)
        s = Digest::SHA3.new(256)
        data.each {|i| s.update(i)}
        s.digest
      end

      def secret_compare(s1, s2)
        s1.size == s2.size && s1.each_byte.each_with_index.map {|b, i| b ^ s2[i].ord}.reduce(0, :+) == 0
      end

      def big_endian_encode(n, zero = '')
        if n == 0
          zero
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
    end

  end
end