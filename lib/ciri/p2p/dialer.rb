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


require 'async/io'
require 'async/io/stream'
require_relative 'rlpx/connection'

module Ciri
  module P2P
    # Discovery and dial new nodes
    class Dialer
      include RLPX

      def initialize(private_key:, handshake:)
        @private_key = private_key
        @handshake = handshake
      end

      # setup a new connection to node
      def dial(node)
        # connect tcp socket
        # Use Stream to buffer IO operation
        address = node.addresses&.first
        return unless address
        socket = Async::IO::Stream.new(Async::IO::Endpoint.tcp(address.ip, address.tcp_port).connect)
        c = Connection.new(socket)
        c.encryption_handshake!(private_key: @private_key, remote_node_id: node.node_id)
        remote_handshake = c.protocol_handshake!(@handshake)
        [c, remote_handshake]
      end
    end
  end
end

