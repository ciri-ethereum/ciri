# frozen_string_literal: true
#
# RLPX
require 'ethruby/rlp/serializable'

module ETH
  module DevP2P
    module RLPX

      # RLPX message
      class Message
        include ETH::RLP::Serializable

        schema [
                 {code: :int},
                 {size: :int},
                 :payload,
                 :received_at
               ]
        default_data(received_at: nil)
      end

    end
  end
end
