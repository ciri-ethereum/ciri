# frozen_string_literal: true
#
# RLPX
require 'ethruby/key'
require 'ethruby/rlp/serializable'

module Eth
  module DevP2P
    module RLPX
      MESSAGES = {
        handshake: 0x00,
        discover: 0x01,
        ping: 0x02,
        pong: 0x03
      }.freeze

      BASE_PROTOCOL_VERSION = 5
      BASE_PROTOCOL_LENGTH = 16
      BASE_PROTOCOL_MAX_MSG_SIZE = 2 * 1024
      SNAPPY_PROTOCOL_VERSION = 5

      ### messages

      class AuthMsgV4
        include Eth::RLP::Serializable

        schema [
                 :signature,
                 :initiator_pubkey,
                 :nonce,
                 {version: :int}
               ]

        # keep this field let client known how to format(plain or eip8)
        attr_accessor :got_plain
      end

      class AuthRespV4
        include Eth::RLP::Serializable

        schema [
                 :random_pubkey,
                 :nonce,
                 {version: :int}
               ]
      end
    end
  end
end