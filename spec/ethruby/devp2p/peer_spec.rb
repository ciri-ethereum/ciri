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
      attr_reader :histories, :peer, :protocol_io

      def initialize(*args)
        super(*args)
        @histories = []
      end

      def start(peer, io)
        @peer = peer
        @protocol_io = io
        super
      end

      def handle_msg(msg)
        histories << msg
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
    expect(protocol_1.protocol_io.io).to be connection
    expect(protocol_1.histories).to eq [msg_1, msg_2]

    # old 'eth' protocol
    protocol_2.send_stop
    protocol_2.wait
    expect(protocol_2.peer).to be peer
    expect(protocol_2.protocol_io.io).to be connection
    expect(protocol_2.histories).to eq []

    # 'hello' protocol
    protocol_3.send_stop
    protocol_3.wait
    expect(protocol_3.peer).to be peer
    expect(protocol_3.protocol_io.io).to be connection
    expect(protocol_3.histories).to eq [msg_3]
  end
end
