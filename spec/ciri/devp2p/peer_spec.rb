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


require 'spec_helper'
require 'async'
require 'ciri/devp2p/peer'
require 'ciri/devp2p/protocol'
require 'ciri/devp2p/rlpx/protocol_handshake'
require 'concurrent'

RSpec.describe Ciri::DevP2P::Peer do
  # mock connection
  let(:connection) do
    Class.new do
      attr_reader :queue

      def initialize
        @queue = []
      end

      def read_msg
        raise StandardError.new("empty queue") if queue.empty?
        queue.shift
      end

      def close
      end

      def closed?
        @queue.empty?
      end
    end.new
  end

  it 'handle msg by code' do
    protocol_1 = Ciri::DevP2P::Protocol.new(name: 'eth', version: 63, length: 17)
    protocol_2 = Ciri::DevP2P::Protocol.new(name: 'eth', version: 62, length: 8)
    protocol_3 = Ciri::DevP2P::Protocol.new(name: 'hello', version: 1, length: 16)

    caps = [
        Ciri::DevP2P::RLPX::Cap.new(name: 'eth', version: 63),
        Ciri::DevP2P::RLPX::Cap.new(name: 'eth', version: 62),
        Ciri::DevP2P::RLPX::Cap.new(name: 'hello', version: 1),
    ]
    handshake = Ciri::DevP2P::RLPX::ProtocolHandshake.new(version: 4, name: 'test', caps: caps, id: 0)


    msg_1 = Ciri::DevP2P::RLPX::Message.new(code: 16, payload: "test_1".b, size: 6)
    msg_2 = Ciri::DevP2P::RLPX::Message.new(code: 32, payload: "test_2".b, size: 6)
    msg_3 = Ciri::DevP2P::RLPX::Message.new(code: 33, payload: "test_hello".b, size: 10)

    # send messages to connection
    connection.queue << msg_1
    connection.queue << msg_2
    connection.queue << msg_3

    peer = Ciri::DevP2P::Peer.new(connection, handshake, [protocol_1, protocol_2, protocol_3])

    Async::Reactor.run do |task|
      task.reactor.after(5) do
        raise StandardError.new("test timeout.. must something be wrong")
      end

      task.async do
        # peer read all messages
        expect {peer.start_handling}.to raise_error(StandardError, "empty queue")

        # 'eth' protocol
        protocol_io_1 = peer.protocol_ios.find {|p| p.protocol == protocol_1}
        expect(protocol_io_1.read_msg).to eq msg_1
        expect(protocol_io_1.read_msg).to eq msg_2
        expect(protocol_io_1.empty?).to be_truthy

        # old 'eth' protocol
        protocol_io_2 = peer.protocol_ios.find {|p| p.protocol == protocol_2}
        expect(protocol_io_2).to be_nil

        # 'hello' protocol
        protocol_io_3 = peer.protocol_ios.find {|p| p.protocol == protocol_3}
        expect(protocol_io_3.read_msg).to eq msg_3
        expect(protocol_io_3.empty?).to be_truthy
        task.reactor.stop
      end
    end
  end
end
