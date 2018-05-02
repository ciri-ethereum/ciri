require 'openssl'
require 'secp256k1'
require_relative 'crypto'

module Eth

  # Eth::Key represent private/public key pair, it support several encryption methods used in Ethereum
  #
  # Examples:
  #
  #   key = Eth::Key.random
  #   key.ecdsa_signature(data)
  #
  class Key

    class << self
      def ecdsa_recover(msg, signature)
        pk = Secp256k1::PrivateKey.new(flags: Secp256k1::ALL_FLAGS)
        sig, recid = signature[0..-2], Eth::Utils.big_endian_decode(signature[-1])

        recsig = pk.ecdsa_recoverable_deserialize(sig, recid)
        pubkey = pk.ecdsa_recover(msg, recsig)

        Eth::Key.new(raw_public_key: Secp256k1::PublicKey.new(pubkey: pubkey).serialize(compressed: false))
      end

      def random
        ec_key = OpenSSL::PKey::EC.new('secp256k1')
        ec_key.generate_key
        Eth::Key.new(ec_key: ec_key)
      end
    end

    attr_reader :ec_key

    # initialized from ec_key or raw keys
    # ec_key is a OpenSSL::PKey::EC object, raw keys is bytes presented keys
    def initialize(ec_key: nil, raw_public_key: nil, raw_private_key: nil)
      @ec_key = ec_key || Eth::Utils.create_ec_pk(raw_privkey: raw_private_key, raw_pubkey: raw_public_key)
    end

    # raw public key
    def raw_public_key
      @raw_public_key ||= ec_key.public_key.to_bn.to_s(2)
    end

    def ecdsa_signature(data)
      signature, recid = secp256k1_key.ecdsa_recoverable_serialize(secp256k1_key.ecdsa_sign_recoverable(data))
      signature + Eth::Utils.big_endian_encode(recid, "\x00")
    end

    def ecies_encrypt(message, shared_mac_data = '')
      Crypto.ecies_encrypt(message, ec_key, shared_mac_data)
    end

    def ecies_decrypt(data, shared_mac_data = '')
      Crypto.ecies_decrypt(data, ec_key, shared_mac_data)
    end

    private
    def secp256k1_key
      @secp256k1_key ||= Secp256k1::PrivateKey.new(privkey: ec_key.private_key.to_s(2))
    end
  end
end