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
require 'ciri/p2p/errors'
require 'ciri/p2p/network_state'
require 'ciri/p2p/peer_store'
require 'ciri/p2p/protocol'
require 'ciri/p2p/rlpx/protocol_handshake'

RSpec.describe Ciri::P2P::NetworkState do
  let(:eth_protocol) {mock_protocol_class.new(name: 'eth', version: 63, length: 17)}
  let(:old_eth_protocol) {mock_protocol_class.new(name: 'eth', version: 62, length: 8)}
  let(:hello_protocol) {mock_protocol_class.new(name: 'hello', version: 1, length: 16)}
  let(:caps) {[
    Ciri::P2P::RLPX::Cap.new(name: 'eth', version: 63),
    Ciri::P2P::RLPX::Cap.new(name: 'eth', version: 62),
    Ciri::P2P::RLPX::Cap.new(name: 'hello', version: 1),
  ]}
  let(:handshake){Ciri::P2P::RLPX::ProtocolHandshake.new(version: 4, name: 'test', caps: caps, id: "\x00".b * 32)}
  let(:handshake_only_hello){Ciri::P2P::RLPX::ProtocolHandshake.new(version: 4, name: 'test', caps: [Ciri::P2P::RLPX::Cap.new(name: 'hello', version: 1)], id: "\x01".b * 32)}
  let(:handshake_only_hi){Ciri::P2P::RLPX::ProtocolHandshake.new(version: 4, name: 'test', caps: [Ciri::P2P::RLPX::Cap.new(name: 'hi', version: 1)], id: "\x01".b * 32)}
  let(:protocols){[
    eth_protocol,
    old_eth_protocol,
    hello_protocol
  ]}
  let(:peer_store) {
    Ciri::P2P::PeerStore.new
  }

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

  let(:mock_protocol_class) do
    Class.new(Ciri::P2P::Protocol) do

      attr_reader :protocol_initialized, :connected_peers, :disconnected_peers

      def initialized
        @protocol_initialized = true
        @connected_peers = []
        @disconnected_peers = []
      end

      def connected(context)
        @connected_peers << context.peer
      end

      def disconnected(context)
        @disconnected_peers << context.peer
      end
    end
  end

  it 'handle peers connected and removed' do
    network_state = Ciri::P2P::NetworkState.new(protocols: protocols, peer_store: peer_store)

    Async::Reactor.run do |task|
      task.reactor.after(5) do
        raise StandardError.new("test timeout.. must something be wrong")
      end

      task.async do
        network_state.initialize_protocols
        network_state.new_peer_connected(connection, handshake, way_for_connection: :incoming)
        network_state.new_peer_connected(connection, handshake_only_hello, way_for_connection: :incoming)
        task.reactor.stop
      end
    end

    # check eth_protocol
    expect(eth_protocol.protocol_initialized).to be_truthy
    expect(eth_protocol.connected_peers.size).to eq 1
    expect(eth_protocol.disconnected_peers.size).to eq 1
    # check old_eth_protocol
    expect(old_eth_protocol.protocol_initialized).to be_truthy
    expect(old_eth_protocol.connected_peers.size).to eq 0
    # check hello_protocol
    expect(hello_protocol.protocol_initialized).to be_truthy
    expect(hello_protocol.connected_peers.size).to eq 2
    expect(hello_protocol.disconnected_peers.size).to eq 2
  end

  it 'refuse peer connection if cannot match any protocols' do
    network_state = Ciri::P2P::NetworkState.new(protocols: protocols, peer_store: peer_store)
    Async::Reactor.run do |task|
      task.reactor.after(5) do
        raise StandardError.new("test timeout.. must something be wrong")
      end

      task.async do
        network_state.initialize_protocols
        expect do
          network_state.new_peer_connected(connection, handshake_only_hello, way_for_connection: :incoming)
        end.not_to raise_error
        expect do
          network_state.new_peer_connected(connection, handshake_only_hi, way_for_connection: :incoming)
        end.to raise_error(Ciri::P2P::UselessPeerError)
        task.reactor.stop
      end
    end
  end

end


