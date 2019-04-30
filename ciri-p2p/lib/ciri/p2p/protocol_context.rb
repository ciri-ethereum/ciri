# frozen_string_literal: true


# Copyright (c) 2018 by Jiang Jinyang <jjyruby@gmail.com>
# 
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
# 
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
# 
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


require 'forwardable'

module Ciri
  module P2P

    # ProtocolContext is used to manuaplate
    class ProtocolContext

      extend Forwardable

      attr_reader :peer, :protocol, :protocol_io

      def_delegators :@network_state, :local_node_id

      def initialize(network_state, peer: nil, protocol: nil, protocol_io: nil)
        @network_state = network_state
        @peer = peer
        @protocol = protocol
        @protocol_io = protocol_io
      end

      def send_data(code, data, peer: self.peer, protocol: self.protocol.name)
        ensure_peer(peer).find_protocol_io(protocol).send_data(code, data)
      end

      def raw_local_node_id
        @raw_local_node_id ||= local_node_id.to_bytes
      end

      def peers
        @network_state.peers.values
      end

      def find_peer(raw_node_id)
        @network_state.peers[raw_node_id]
      end

      private

      def ensure_peer(peer)
        return peer if peer.is_a?(P2P::Peer)
        @network_state.peers[peer]
      end
    end

  end
end

