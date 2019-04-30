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
require 'ciri/p2p/server'
require 'ciri/p2p/protocol'
require 'ciri/p2p/node'
require 'ciri/p2p/rlpx/protocol_handshake'

RSpec.describe Ciri::P2P::Server do
  context 'dial node' do
    let(:key) do
      Ciri::Key.random
    end

    it 'connecting to bootnodes after started' do
      bootnode = Ciri::P2P::Node.new(
        node_id: Ciri::P2P::NodeID.new(key),
        addresses: [
          Ciri::P2P::Address.new(
            ip: "127.0.0.1",
            udp_port: 42,
            tcp_port: 42,
          )
        ]
      )
      server = Ciri::P2P::Server.new(private_key: key, protocols: [], bootnodes: [bootnode], tcp_port: 0)
      allow(server.dialer).to receive(:dial) {|node| raise StandardError.new("dial error ip:#{node.addresses[0].ip}, tcp_port:#{node.addresses[0].tcp_port}")}
      expect do
        server.run
      end.to raise_error(StandardError, "dial error ip:#{bootnode.addresses[0].ip}, tcp_port:#{bootnode.addresses[0].tcp_port}")
    end
  end

  context('connect peers') do
    let(:mock_protocol_class) do
      Class.new(Ciri::P2P::Protocol) do

        attr_reader :raw_local_node_id, :received_messages, :connected_peers, :disconnected_peers
        attr_accessor :stop

        def initialized(context)
          @raw_local_node_id = context.raw_local_node_id
          @connected_peers = []
          @received_messages = []
          @disconnected_peers = []
          @stop = false
        end

        def received(context, msg)
          return if @stop
          @received_messages << msg
        end

        def connected(context)
          return if @stop
          @connected_peers << context.peer
          context.send_data(1, "hello from #{Ciri::Utils.to_hex @raw_local_node_id}")
        end

        def disconnected(context)
          return if @stop
          @disconnected_peers << context.peer
        end
      end
    end

    def mock_protocol
      mock_protocol_class.new(name: 'moc', version: 63, length: 17)
    end

    def new_node(protocols:, bootnodes: [])
      private_key = Ciri::Key.random
      Ciri::P2P::Server.new(
        private_key: private_key,
        protocols: protocols,
        bootnodes: bootnodes,
        tcp_port: 0,
        udp_port: 0,
        ping_interval_secs: 1,
        discovery_interval_secs: 0.5,
        dial_outgoing_interval_secs: 0.5)
    end

    it "3 nodes connect each other" do
      protocols = 3.times.map{ mock_protocol }
      # setup 3 nodes
      bootnode = new_node(protocols: [protocols[0]])
      node1 = nil
      node2 = nil

      bootnode_task = nil
      node1_task = nil
      node2_task = nil

      Async::Reactor.run do |task|
        bootnode_task = task.async do
          bootnode.run
        end

        task.reactor.after(0.1) do
          node1_task = task.async do
            task.sleep(0.1) while bootnode.udp_port.zero? || bootnode.tcp_port.zero?
            node1 = new_node(protocols: [protocols[1]], bootnodes: [bootnode.to_node])
            node1.run
          end
          node2_task = task.async do
            task.sleep(0.1) while bootnode.udp_port.zero? || bootnode.tcp_port.zero?
            node2 = new_node(protocols: [protocols[2]], bootnodes: [bootnode.to_node])
            node2.run
          end
        end

        # wait.. and check each node result
        task.reactor.after(5) do
          task.async do
            # wait few seconds...
            wait_seconds = 0
            sleep_interval = 0.3
            while wait_seconds < 15 && protocols.any?{|proto| proto.received_messages.count < 2}
              task.sleep(sleep_interval)
              wait_seconds += sleep_interval
            end

            # check peers attributes
            protocols.each do |proto|
              expect(proto.raw_local_node_id).not_to be_nil
              expect(proto.connected_peers.count - proto.disconnected_peers.count).to eq 2
            end
            # because duplicate connection during booting phase, we maybe have few disconnected peer
            list_of_disconnected_peers_count = protocols.map{|protocol| protocol.disconnected_peers.count }
            # node received 2 messages
            expect(protocols[0].received_messages.count).to eq 2
            expect(protocols[1].received_messages.count).to eq 2
            expect(protocols[2].received_messages.count).to eq 2
            # test disconnected_peers
            bootnode.disconnect_all
            node1.disconnect_all
            node2.disconnect_all
            protocols.each {|protocol| protocol.stop = true }
            task.sleep(0.5)
            # stop all async task
            bootnode_task.stop
            node1_task.stop
            node2_task.stop
            protocols.each_with_index do |protocol, i|
              expect(protocol.disconnected_peers.count - list_of_disconnected_peers_count[i]).to eq 2
            end
            task.reactor.stop
          end
        end

      end
    end

  end

end

