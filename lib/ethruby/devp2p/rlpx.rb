# frozen_string_literal: true
#
# RLPX
require 'secp256k1'
require_relative 'message'

module Eth
  module DevP2P
    module RLPX

      SHA_LENGTH = 32
      ECIES_OVERHEAD = 65 + 16 + 32

      ### messages

      class AuthMsgV4 < Eth::DevP2P::Message
        schema [
                 {got_plain: :bool},
                 :signature,
                 :initiator_pubkey,
                 {nonce: [:int]},
                 {version: :int}
               ]
        default_data(got_plain: false)

        def seal_eip8(remote_key)
          encoded = rlp_encode!
          # pad
          encoded += ([0] * rand(100..300)).pack('c*')
          prefix = Utils.big_endian_encode(encoded.size)
          enc = Devp2p::Crypto.ecies_encrypt(encoded, remote_key, prefix)
          prefix + enc
        end
      end

      class AuthRespV4 < Eth::DevP2P::Message
        schema [
                 :random_pubkey,
                 {nonce: [:int]},
                 {version: :int}
               ]

        # def seal_eip8(remote_key)
        #   encoded = rlp_encode!
        #   # pad
        #   encoded += ([0] * rand(100..300)).pack('c*')
        #   prefix = Utils.big_endian_encode(encoded.size)
        #   enc = Devp2p::Crypto.ecies_encrypt(encoded, remote_key, prefix)
        #   prefix + enc
        # end
      end

      # handle handshake protocols
      class HandShake
        attr_reader :private_key, :remote_key, :remote_random_pubkey, :nonce_bytes, :remote_nonce_bytes

        def initialize(private_key:, remote_key:)
          @private_key = private_key
          @remote_key = remote_key
        end

        def random_privkey
          @random_privkey ||= Secp256k1::PrivateKey.new
        end

        def auth_msg
          # make nonce bytes
          nonce = SHA_LENGTH.times.map {rand(8)}
          @nonce_bytes = nonce
          # remote first byte tag
          token = private_key.dh_compute_key(remote_key.public_key)
          raise StandardError.new("token size #{token.size} not correct") if token.size != nonce.size
          # xor
          signed = xor(token, nonce)

          signature = ecdsa_signature(random_privkey, signed)
          initiator_pubkey = private_key.public_key.to_bn.to_s(2)[1..-1]
          AuthMsgV4.new(signature: signature, initiator_pubkey: initiator_pubkey, nonce: nonce, version: 4)
        end

        def handle_auth_msg(msg)
          #Eth::Utils.create_ec_pk(raw_pubkey: raw_pubkey, raw_privkey: raw_privkey)
          remote_key = Utils.create_ec_pk(raw_pubkey: "\x04" + msg.initiator_pubkey)
          @remote_nonce_bytes = msg.nonce

          token = private_key.dh_compute_key(remote_key.public_key)
          signed = xor(token, msg.nonce)
          @remote_random_pubkey = ecdsa_recover(signed, msg.signature)
        end

        def auth_ack_msg
          # make nonce bytes
          nonce = SHA_LENGTH.times.map {rand(8)}
          @nonce_bytes = nonce
          random_pubkey = random_privkey.pubkey.serialize(compressed: false)[1..-1]
          AuthRespV4.new(random_pubkey: random_pubkey, nonce: nonce, version: 4)
        end

        def handle_auth_ack_msg(msg)
          # make nonce bytes
          @remote_nonce_bytes = msg.nonce
          @remote_random_pubkey = Secp256k1::PublicKey.new(pubkey: "\x04" + msg.random_pubkey, raw: true)
        end

        private
        def ecdsa_signature(key, data)
          signature, recid = key.ecdsa_recoverable_serialize(key.ecdsa_sign_recoverable(data))
          signature + (recid.zero? ? "\x00" : Eth::Utils.big_endian_encode(recid))
        end

        def ecdsa_recover(msg, signature)
          pk = Secp256k1::PrivateKey.new(flags: Secp256k1::ALL_FLAGS)
          sig, recid = signature[0..-2], Eth::Utils.big_endian_decode(signature[-1])

          recsig = pk.ecdsa_recoverable_deserialize(sig, recid)
          pubkey = pk.ecdsa_recover(msg, recsig)

          Secp256k1::PublicKey.new(pubkey: pubkey)
        end

        def xor(b1, b2)
          b1.each_byte.with_index.map {|b, i| b ^ b2[i]}.pack('c*')
        end

      end
    end
  end
end
