# frozen_string_literal: true

require 'ethruby/rlp/serializable'

module ETH
  module DevP2P
    module RLPX

      class Cap
        include ETH::RLP::Serializable

        schema [
                 :name,
                 {version: :int}
               ]
      end

      # handle protocol handshake
      class ProtocolHandshake
        include ETH::RLP::Serializable

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
