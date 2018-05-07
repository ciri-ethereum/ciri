# frozen_string_literal: true

require_relative 'rlpx/node'

module ETH
  module DevP2P

    # represent a connected remote node
    class Peer
      def initialize(connection, handshake, protocols)
        @connection = connection
        @handshake = handshake
      end

      def node_id
        @node_id ||= RLPX::NodeID.from_raw_id(@handshake.id)
      end
    end

  end
end