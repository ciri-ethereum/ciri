# frozen_string_literal: true

require_relative 'rlpx'
require_relative 'actor'

module ETH
  module DevP2P

    # represent a connected remote node
    class Peer

      class UnknownMessageCodeError < StandardError
      end

      # helper class for send/read sub protocol msg
      class ProtocolIO
        attr_reader :protocol, :offset, :io

        def initialize(protocol, offset, io)
          @protocol = protocol
          @offset = offset
          @io = io
        end
      end

      include Actor

      attr_reader :connection

      def initialize(connection, handshake, protocols)
        @connection = connection
        @handshake = handshake
        @protocols = protocols
        @protocol_io_hash = make_protocol_io_hash(protocols, handshake.caps, connection)
        super()
      end

      def node_id
        @node_id ||= RLPX::NodeID.from_raw_id(@handshake.id)
      end

      # start peer
      # handle msg, handle sub protocols
      def start
        executor.post {read_loop}
        start_protocols
        super
      end

      # read and handle msg
      def read_loop
        loop do
          msg = connection.read_msg
          msg.received_at = Time.now
          handle(msg)
        end
      end

      def start_protocols
        @protocols.each do |protocol|
          protocol.start(self, @protocol_io_hash[protocol.name])
        end
      end

      def handle(msg)
        if msg.code == RLPX::MESSAGES[:ping]
          #TODO send pong
        else
          # send msg to sub protocol
          if (protocol = find_protocol_by_msg_code(msg.code)).nil?
            raise UnknownMessageCodeError.new("can't find protocol with msg code #{msg.code}")
          end
          protocol << [:handle_msg, msg]
        end
      end

      private
      def find_protocol_by_msg_code(code)
        @protocols.find do |protocol|
          code >= protocol.offset && code <= protocol.offset + protocol.length
        end
      end

      # return protocol_io_hash
      # handle multiple sub protocols upon one io
      def make_protocol_io_hash(protocols, caps, io)
        # sub protocol offset
        offset = RLPX::BASE_PROTOCOL_LENGTH
        result = {}
        # [name, version] as key
        protocols_hash = protocols.map {|protocol| [protocol.name, protocol.version]}.to_h
        sorted_caps = caps.sort_by {|c| [c.name, c.version]}

        sorted_caps.each do |cap|
          protocol = protocols_hash[[cap.name, cap.version]]
          next unless protocol
          # ignore same name old protocols
          if (old = result[cap.name])
            result.delete(cap.name)
            offset -= old.length
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