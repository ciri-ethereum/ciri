# frozen_string_literal: true

require_relative 'actor'

module ETH
  module DevP2P

    # protocol represent DevP2P sub protocols
    class Protocol

      include Actor

      attr_reader :name, :version, :length
      attr_accessor :node_info, :peer_info

      def initialize(name:, version:, length:)
        @name = name
        @version = version
        @length = length
        super()
      end

      # start protocol handling
      def start(peer, io)
        super()
      end
    end

  end
end
