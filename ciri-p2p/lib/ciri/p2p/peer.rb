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


require 'ciri/utils'
require 'ciri/rlp'
require_relative 'rlpx'
require_relative 'protocol_io'

module Ciri
  module P2P

    # represent a connected remote node
    class Peer
      OUTBOUND = :outbound
      INBOUND = :inbound

      attr_reader :connection, :direction

      def initialize(connection, handshake, protocols, direction:)
        @connection = connection
        @handshake = handshake
        @protocols = protocols
        @protocol_io_hash = make_protocol_io_hash(protocols, handshake.caps, connection)
        @direction = direction
      end

      def outgoing?
        @direction == OUTBOUND
      end

      def incoming?
        @direction == INBOUND
      end

      def to_s
        @display_name ||= begin
          Utils.to_hex(node_id.id)[0..8]
        end
      end

      def inspect
        "<Peer:#{to_s} direction: #{@direction}>"
      end

      def hash
        raw_node_id.hash
      end

      def ==(peer)
        self.class == peer.class && raw_node_id == peer.raw_node_id
      end

      alias eql? ==

      # get id of node in bytes form
      def raw_node_id
        node_id.to_bytes
      end

      # get NodeID object
      def node_id
        @node_id ||= NodeID.from_raw_id(@handshake.id)
      end
      
      # disconnect peer connections
      def disconnect
        @connection.close
      end

      def disconnected?
        @connection.closed?
      end

      def protocol_ios
        @protocol_io_hash.values
      end

      def find_protocol(name)
        @protocol.find do |protocol|
          protocol.name == name
        end
      end

      def find_protocol_io(name)
        protocol_ios.find do |protocol_io|
          protocol_io.protocol.name == name
        end
      end

      # find ProtocolIO by raw message code
      # used by DEVP2P to find stream of sub-protocol
      def find_protocol_io_by_msg_code(raw_code)
        @protocol_io_hash.values.find do |protocol_io|
          offset = protocol_io.offset
          protocol = protocol_io.protocol
          raw_code >= offset && raw_code < offset + protocol.length
        end
      end

      private

      # return protocol_io_hash
      # handle multiple sub protocols upon one io
      def make_protocol_io_hash(protocols, caps, io)
        # sub protocol offset
        offset = RLPX::BASE_PROTOCOL_LENGTH
        result = {}
        # [name, version] as key
        protocols_hash = protocols.map {|protocol| [[protocol.name, protocol.version], protocol]}.to_h
        sorted_caps = caps.sort_by {|c| [c.name, c.version]}

        sorted_caps.each do |cap|
          protocol = protocols_hash[[cap.name, cap.version]]
          next unless protocol
          # ignore same name old protocols
          if (old = result[cap.name])
            result.delete(cap.name)
            offset -= old.protocol.length
          end
          result[cap.name] = ProtocolIO.new(protocol, offset, io)
          # move offset, to support next protocol
          offset += protocol.length
        end
        result
      end
    end

  end
end

