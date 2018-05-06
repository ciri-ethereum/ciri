# frozen_string_literal: true
#
# RLPX
require 'ethruby/key'

module Eth
  module DevP2P
    module RLPX

      # present node id
      class NodeID

        class << self
          def from_raw_id(raw_id)
            NodeID.new(Eth::Key.new(raw_public_key: "\x04".b + raw_id))
          end
        end

        attr_reader :public_key

        alias key public_key

        def initialize(public_key)
          unless public_key.is_a?(Eth::Key)
            raise TypeError.new("expect Eth::Key but get #{public_key.class}")
          end
          @public_key = public_key
        end

        def id
          @id ||= key.raw_public_key[1..-1]
        end

        def == (other)
          self.class == other.class && id == other.id
        end
      end

      class Node
        attr_reader :node_id, :ip, :udp_port, :tcp_port, :added_at

        def initialize(node_id:, ip:, udp_port:, tcp_port:, added_at: nil)
          @node_id = node_id
          @ip = ip
          @udp_port = udp_port
          @tcp_port = tcp_port
          @added_at = added_at
        end

        def == (other)
          self.class == other.class && node_id == other.node_id
        end
      end

    end
  end
end
