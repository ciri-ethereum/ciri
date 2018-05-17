# frozen_string_literal: true

# Copyright (c) 2018, by Jiang Jinyang. <https://justjjy.com>
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
