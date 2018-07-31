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


require 'spec_helper'
require 'ciri/actor'
require 'ciri/devp2p/peer'
require 'ciri/devp2p/protocol'
require 'ciri/devp2p/rlpx/protocol_handshake'
require 'concurrent'

RSpec.describe Ciri::DevP2P::Peer do
  before {Ciri::Actor.default_executor = Concurrent::CachedThreadPool.new}
  after do
    Ciri::Actor.default_executor.kill
    Ciri::Actor.default_executor = nil
  end

  # mock connection
  let(:connection) do
    Class.new do
      attr_reader :queue

      def initialize
        @queue = []
      end

      def read_msg
        raise StandardError if queue.empty?
        queue.shift
      end
    end.new
  end

  let(:mock_protocol) do
    Class.new(Ciri::DevP2P::Protocol) do
      attr_reader :peer, :protocol_io

      def start(peer, io)
        @peer = peer
        @protocol_io = io
      end
    end
  end

  it 'handle msg by code' do
    protocol_1 = mock_protocol.new(name: 'eth', version: 63, length: 17)
    protocol_2 = mock_protocol.new(name: 'eth', version: 62, length: 8)
    protocol_3 = mock_protocol.new(name: 'hello', version: 1, length: 16)

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
    peer.start

    # peer read all messages
    expect {peer.wait}.to raise_error(StandardError)

    # 'eth' protocol
    expect(protocol_1.peer).to be peer
    expect(protocol_1.protocol_io.read_msg).to eq msg_1
    expect(protocol_1.protocol_io.read_msg).to eq msg_2
    expect(protocol_1.protocol_io.msg_queue.empty?).to be_truthy

    # old 'eth' protocol
    expect(protocol_2.peer).to be peer
    expect(protocol_2.protocol_io.msg_queue.empty?).to be_truthy

    # 'hello' protocol
    expect(protocol_3.peer).to be peer
    expect(protocol_3.protocol_io.read_msg).to eq msg_3
    expect(protocol_3.protocol_io.msg_queue.empty?).to be_truthy
  end
end
