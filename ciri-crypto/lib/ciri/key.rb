# frozen_string_literal: true

# Copyright (c) 2018, by Jiang Jinyang. <https://justjjy.com>, classicalliu.
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


require 'openssl'
require 'ciri/utils'
require_relative 'crypto'

module Ciri

  # Ciri::Key represent private/public key pair, it support several encryption methods used in Ethereum
  #
  # Examples:
  #
  #   key = Ciri::Key.random
  #   key.ecdsa_signature(data)
  #
  class Key

    class << self
      def ecdsa_recover(msg, signature)
        raw_public_key = Crypto.ecdsa_recover(msg, signature, return_raw_key: true)
        Ciri::Key.new(raw_public_key: raw_public_key)
      end

      def random
        ec_key = OpenSSL::PKey::EC.new('secp256k1')
        ec_key.generate_key
        Ciri::Key.new(ec_key: ec_key)
      end
    end

    attr_reader :ec_key

    # initialized from ec_key or raw keys
    # ec_key is a OpenSSL::PKey::EC object, raw keys is bytes presented keys
    def initialize(ec_key: nil, raw_public_key: nil, raw_private_key: nil)
      @ec_key = ec_key || Ciri::Utils.create_ec_pk(raw_privkey: raw_private_key, raw_pubkey: raw_public_key)
    end

    # raw public key
    def raw_public_key
      @raw_public_key ||= ec_key.public_key.to_bn.to_s(2)
    end

    def ecdsa_signature(data)
      Crypto.ecdsa_signature(secp256k1_key, data)
    end

    def ecies_encrypt(message, shared_mac_data = '')
      Crypto.ecies_encrypt(message, ec_key, shared_mac_data)
    end

    def ecies_decrypt(data, shared_mac_data = '')
      Crypto.ecies_decrypt(data, ec_key, shared_mac_data)
    end

    private

    def secp256k1_key
      privkey = ec_key.private_key.to_s(2)
      # some times below error will occurs, raise error with more detail
      unless privkey.instance_of?(String) && privkey.size == 32
        raise ArgumentError, "privkey must be composed of 32 bytes, #{bytes}: #{privkey.size} privkey: #{Utils.to_hex privkey}"
      end
      @secp256k1_key ||= Crypto.ensure_secp256k1_key(privkey: privkey)
    end
  end
end