# frozen_string_literal: true
#
# RLPX
require 'ethruby/key'
require_relative 'secrets'

module Eth
  module DevP2P
    module RLPX

      SHA_LENGTH = 32
      ECIES_OVERHEAD = 65 + 16 + 32

      # handle handshake protocols
      class HandShake
        attr_reader :private_key, :remote_key, :remote_random_key, :nonce_bytes, :remote_nonce_bytes, :remote_id

        def initialize(private_key:, remote_id:)
          @private_key = private_key
          @remote_id = remote_id
        end

        def remote_key
          @remote_id.key
        end

        def random_key
          @random_key ||= Eth::Key.random
        end

        def auth_msg
          # make nonce bytes
          nonce = random_nonce(SHA_LENGTH)
          @nonce_bytes = nonce
          # remote first byte tag
          token = dh_compute_key(private_key, remote_key)
          raise StandardError.new("token size #{token.size} not correct") if token.size != nonce.size
          # xor
          signed = xor(token, nonce)

          signature = random_key.ecdsa_signature(signed)
          initiator_pubkey = private_key.raw_public_key[1..-1]
          AuthMsgV4.new(signature: signature, initiator_pubkey: initiator_pubkey, nonce: nonce, version: 4)
        end

        def handle_auth_msg(msg)
          remote_key = Eth::Key.new(raw_public_key: "\x04" + msg.initiator_pubkey)
          @remote_nonce_bytes = msg.nonce

          token = dh_compute_key(private_key, remote_key)
          signed = xor(token, msg.nonce)
          @remote_random_key = Eth::Key.ecdsa_recover(signed, msg.signature)
        end

        def auth_ack_msg
          # make nonce bytes
          nonce = random_nonce(SHA_LENGTH)
          @nonce_bytes = nonce
          random_pubkey = random_key.raw_public_key[1..-1]
          AuthRespV4.new(random_pubkey: random_pubkey, nonce: nonce, version: 4)
        end

        def handle_auth_ack_msg(msg)
          # make nonce bytes
          @remote_nonce_bytes = msg.nonce
          @remote_random_key = Eth::Key.new(raw_public_key: "\x04" + msg.random_pubkey)
        end

        def extract_secrets
          secret = dh_compute_key(random_key, remote_random_key)
          shared_secret = Eth::Utils.sha3(secret, Eth::Utils.sha3(nonce_bytes, remote_nonce_bytes))
          aes_secret = Eth::Utils.sha3(secret, shared_secret)
          mac = Eth::Utils.sha3(secret, aes_secret)
          Secrets.new(remote_id: remote_id, aes: aes_secret, mac: mac)
        end

        private

        def dh_compute_key(private_key, public_key)
          private_key.ec_key.dh_compute_key(public_key.ec_key.public_key)
        end

        def xor(b1, b2)
          b1.each_byte.with_index.map {|b, i| b ^ b2[i].ord}.pack('c*')
        end

        def random_nonce(size)
          size.times.map {rand(8)}.pack('c*')
        end

      end
    end
  end
end
