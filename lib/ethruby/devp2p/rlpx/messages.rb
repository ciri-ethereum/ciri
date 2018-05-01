# frozen_string_literal: true
#
# RLPX
require 'ethruby/key'
require 'ethruby/devp2p/serializable'

module Eth
  module DevP2P
    module RLPX

      ### messages

      class AuthMsgV4
        include Eth::DevP2P::Serializable

        schema [
                 {got_plain: :bool},
                 :signature,
                 :initiator_pubkey,
                 :nonce,
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

      class AuthRespV4
        include Eth::DevP2P::Serializable

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
    end
  end
end