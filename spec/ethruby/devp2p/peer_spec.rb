# frozen_string_literal: true

require 'spec_helper'
require 'ethruby/devp2p/peer'
require 'ethruby/devp2p/protocol'
require 'ethruby/devp2p/rlpx/protocol_handshake'
require 'concurrent'

RSpec.describe ETH::DevP2P::Peer do
  let(:executor) {Concurrent::CachedThreadPool.new}
  let(:actor) {my_actor.new(executor: executor)}

  after {executor.kill}

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
    Class.new(ETH::DevP2P::Protocol) do
      attr_reader :peer, :protocol_io

      def start(peer, io)
        @peer = peer
        @protocol_io = io
        super
      end
    end
  end

  it 'handle msg by code' do
    protocol_1 = mock_protocol.new(name: 'eth', version: 63, length: 17)
    protocol_2 = mock_protocol.new(name: 'eth', version: 62, length: 8)
    protocol_3 = mock_protocol.new(name: 'hello', version: 1, length: 16)

    caps = [
      ETH::DevP2P::RLPX::Cap.new(name: 'eth', version: 63),
      ETH::DevP2P::RLPX::Cap.new(name: 'eth', version: 62),
      ETH::DevP2P::RLPX::Cap.new(name: 'hello', version: 1),
    ]
    handshake = ETH::DevP2P::RLPX::ProtocolHandshake.new(version: 4, name: 'test', caps: caps, id: 0)


    msg_1 = ETH::DevP2P::RLPX::Message.new(code: 16, payload: "test_1".b, size: 6)
    msg_2 = ETH::DevP2P::RLPX::Message.new(code: 32, payload: "test_2".b, size: 6)
    msg_3 = ETH::DevP2P::RLPX::Message.new(code: 33, payload: "test_hello".b, size: 10)

    # send messages to connection
    connection.queue << msg_1
    connection.queue << msg_2
    connection.queue << msg_3

    peer = ETH::DevP2P::Peer.new(connection, handshake, [protocol_1, protocol_2, protocol_3])
    peer.executor = executor
    peer.start

    # peer read all messages
    expect {peer.wait}.to raise_error(StandardError)

    # 'eth' protocol
    protocol_1.send_stop
    protocol_1.wait
    expect(protocol_1.peer).to be peer
    expect(protocol_1.protocol_io.read_msg).to eq msg_1
    expect(protocol_1.protocol_io.read_msg).to eq msg_2
    expect(protocol_1.protocol_io.msg_queue.empty?).to be_truthy

    # old 'eth' protocol
    protocol_2.send_stop
    protocol_2.wait
    expect(protocol_2.peer).to be peer
    expect(protocol_2.protocol_io.msg_queue.empty?).to be_truthy

    # 'hello' protocol
    protocol_3.send_stop
    protocol_3.wait
    expect(protocol_3.peer).to be peer
    expect(protocol_3.protocol_io.read_msg).to eq msg_3
    expect(protocol_3.protocol_io.msg_queue.empty?).to be_truthy
  end
end
