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
require 'async/queue'
require 'async/semaphore'
require_relative 'rlpx/message'

module Ciri
  module P2P

    # send/read sub protocol msg
    class ProtocolIO

      class Error < StandardError
      end
      class InvalidMessageCode < Error
      end

      attr_reader :protocol, :offset

      def initialize(protocol, offset, frame_io)
        @protocol = protocol
        @offset = offset
        @frame_io = frame_io
        @msg_queue = Async::Queue.new
        @semaphore = Async::Semaphore.new
      end

      def send_data(code, data)
        @semaphore.acquire do
          msg = RLPX::Message.new(code: code, size: data.size, payload: data)
          write_msg(msg)
        end
      end

      def write_msg(msg)
        raise InvalidMessageCode, "code #{msg.code} must less than length #{protocol.length}" if msg.code > protocol.length
        msg.code += offset
        @frame_io.write_msg(msg)
      end

      def read_msg
        msg = @msg_queue.dequeue
        msg.code -= offset
        msg
      end

      def receive_msg(msg)
        @msg_queue.enqueue msg
      end

      def empty?
        @msg_queue.empty?
      end
    end

  end
end
