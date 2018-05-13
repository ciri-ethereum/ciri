# frozen_string_literal: true

require_relative 'rlpx'
require_relative 'actor'
require_relative 'protocol_io'

module ETH
  module DevP2P

    # represent a connected remote node
    class Peer

      class DiscoverError < StandardError
      end
      class UnknownMessageCodeError < StandardError
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
      rescue StandardError => e
        self << [:raise_error, e]
      end

      def start_protocols
        @protocols.each do |protocol|
          protocol.executor ||= executor
          protocol.start(self, @protocol_io_hash[protocol.name])
        end
      end

      def handle(msg)
        if msg.code == RLPX::MESSAGES[:ping]
          #TODO send pong
        elsif msg.code == RLPX::MESSAGES[:discover]
          reason = RLP.decode(msg.payload).ord
          raise DiscoverError.new("receive error discovery message, reason: #{reason}")
        else
          # send msg to sub protocol
          if (protocol_io = find_protocol_io_by_msg_code(msg.code)).nil?
            raise UnknownMessageCodeError.new("can't find protocol with msg code #{msg.code}")
          end
          protocol_io.msg_queue << msg
        end
      end

      private
      def find_protocol_io_by_msg_code(code)
        @protocol_io_hash.values.find do |protocol_io|
          offset = protocol_io.offset
          protocol = protocol_io.protocol
          code >= offset && code < offset + protocol.length
        end
      end

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
