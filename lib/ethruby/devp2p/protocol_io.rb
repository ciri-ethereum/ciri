# frozen_string_literal: true

require_relative 'actor'
require_relative 'rlpx/message'

module ETH
  module DevP2P

    # send/read sub protocol msg
    class ProtocolIO

      class Error < StandardError
      end
      class InvalidMessageCode < Error
      end

      attr_reader :protocol, :offset, :msg_queue

      def initialize(protocol, offset, frame_io)
        @protocol = protocol
        @offset = offset
        @frame_io = frame_io
        @msg_queue = Queue.new
      end

      def send_data(code, data)
        msg = RLPX::Message.new(code: code, size: data.size, payload: data)
        write_msg(msg)
      end

      def write_msg(msg)
        raise InvalidMessageCode, "code #{code} must less than length #{protocol.length}" if msg.code > protocol.length
        msg.code += offset
        @frame_io.write_msg(msg)
      end

      def read_msg
        msg = msg_queue.pop
        msg.code -= offset
        msg
      end
    end

  end
end
