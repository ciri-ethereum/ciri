# frozen_string_literal: true

require 'ethruby/rlp/serializable'

module Eth
  module DevP2P
    module RLPX

      class Cap
        include Eth::RLP::Serializable

        schema [
                 :name,
                 {version: :int}
               ]
      end

      # handle protocol handshake
      class ProtocolHandshake
        include Eth::RLP::Serializable

        schema [
                 {version: :int},
                 :name,
                 {caps: [Cap]},
                 {listen_port: :int},
                 :id
               ]
        default_data(listen_port: 0)
      end

    end
  end
end
