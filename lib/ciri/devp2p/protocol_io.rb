# frozen_string_literal: true

# Copyright 2018 Jiang Jinyang <https://justjjy.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require 'ciri/actor'
require_relative 'rlpx/message'

module Ciri
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
        @mutex = Mutex.new
      end

      def send_data(code, data)
        @mutex.synchronize do
          msg = RLPX::Message.new(code: code, size: data.size, payload: data)
          write_msg(msg)
        end
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
