# frozen_string_literal: true

module ETH
  module DevP2P

    # protocol represent DevP2P sub protocols
    class Protocol
      attr_accessor :name, :version, :length, :node_info, :peer_info

      def initialize(name:, version:, length:)
        @name = name
        @version = version
        @length = length
      end
    end

  end
end
