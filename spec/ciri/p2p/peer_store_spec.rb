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
require 'ciri/p2p/peer_store'
require 'ciri/p2p/node'
require 'ciri/core_ext'

using Ciri::CoreExt

RSpec.describe Ciri::P2P::PeerStore do

  let(:peer_store) { described_class.new }
  let(:node_id) { Ciri::P2P::NodeID.new(Ciri::Key.random) }
  let(:node_ids) { 10.times.map{Ciri::P2P::NodeID.new(Ciri::Key.random)} }
  let(:ping_hash) { SecureRandom.bytes(10).keccak }

  context 'has_ping?' do
    it '#has_ping?' do
      expect(peer_store.has_ping?(node_id.to_bytes, ping_hash)).to be_falsey
      peer_store.update_ping(node_id.to_bytes, ping_hash)
      expect(peer_store.has_ping?(node_id.to_bytes, ping_hash)).to be_truthy
      expect(peer_store.has_ping?(node_id.to_bytes, ping_hash, expires_in: 0)).to be_falsey
    end
  end

  context 'has_seen?' do
    it '#has_seen?' do
      expect(peer_store.has_seen?(node_id.to_bytes)).to be_falsey
      peer_store.update_last_seen(node_id.to_bytes)
      expect(peer_store.has_seen?(node_id.to_bytes)).to be_truthy
      expect(peer_store.has_seen?(node_id.to_bytes, expires_in: 0)).to be_falsey
    end
  end

  context 'has_ban?' do
    it '#has_ban?' do
      expect(peer_store.has_ban?(node_id.to_bytes)).to be_falsey
      peer_store.ban_peer(node_id.to_bytes)
      expect(peer_store.has_ban?(node_id.to_bytes)).to be_truthy
      expect(peer_store.has_ban?(node_id.to_bytes, now: Time.now + 600)).to be_falsey
    end

    it 'after banned peer' do
      # see and ping peer
      peer_store.update_ping(node_id.to_bytes, ping_hash)
      peer_store.update_last_seen(node_id.to_bytes)
      expect(peer_store.has_ping?(node_id.to_bytes, ping_hash)).to be_truthy
      expect(peer_store.has_seen?(node_id.to_bytes)).to be_truthy
      # after ban
      peer_store.ban_peer(node_id.to_bytes)
      expect(peer_store.has_ping?(node_id.to_bytes, ping_hash)).to be_falsey
      expect(peer_store.has_seen?(node_id.to_bytes)).to be_falsey
    end
  end

  context 'find_bootnodes' do
    it 'return bootnodes' do
      node = Ciri::P2P::Node.new(node_id: node_id, addresses: [])
      peer_store.add_bootnode(node)
      expect(peer_store.find_bootnodes(1)).to eq [node]
      expect(peer_store.find_bootnodes(2)).to eq [node]
    end

    it 'find peers first' do
      node = Ciri::P2P::Node.new(node_id: node_id, addresses: [])
      node2 = Ciri::P2P::Node.new(node_id: node_ids[0], addresses: [])
      peer_store.add_bootnode(node)
      peer_store.add_node(node2)
      expect(peer_store.find_bootnodes(1)).to eq [node]
      expect(peer_store.find_bootnodes(2)).to eq [node, node2]
    end
  end

  context 'find_attempt_peers' do
    it 'return peers' do
      node = Ciri::P2P::Node.new(node_id: node_id, addresses: [])
      peer_store.add_node(node)
      expect(peer_store.find_attempt_peers(1)).to eq [node]
      expect(peer_store.find_attempt_peers(2)).to eq [node]
    end
  end

  context 'report_peer' do
    it 'report peer' do
      node = Ciri::P2P::Node.new(node_id: node_id, addresses: [])
      node2 = Ciri::P2P::Node.new(node_id: node_ids[0], addresses: [])
      peer_store.add_node(node)
      peer_store.add_node(node2)
      peer_store.report_peer(node.raw_node_id, Ciri::P2P::PeerStore::Behaviours::PING)
      # report peer
      expect(peer_store.find_attempt_peers(1)).to eq [node]
      expect(peer_store.find_attempt_peers(2)).to eq [node, node2]
      # update score for reported peers
      peer_store.report_peer(node2.raw_node_id, Ciri::P2P::PeerStore::Behaviours::PING)
      peer_store.report_peer(node2.raw_node_id, Ciri::P2P::PeerStore::Behaviours::PING)
      expect(peer_store.find_attempt_peers(1)).to eq [node2]
      expect(peer_store.find_attempt_peers(2)).to eq [node2, node]
    end
  end

  context 'node' do
    let(:nodes) { node_ids.map {|node_id| Ciri::P2P::Node.new(node_id: node_id, addresses: []) } }
    let(:addresses) do
      [
        Ciri::P2P::Address.new(ip: '127.0.0.1', tcp_port: 3000, udp_port: 3000),
        Ciri::P2P::Address.new(ip: '127.0.0.2', tcp_port: 3000, udp_port: 3000),
        Ciri::P2P::Address.new(ip: '127.0.0.3', tcp_port: 3000, udp_port: 3000),
      ]
    end

    it '#add_node' do
      expect(peer_store.find_attempt_peers(2)).to eq []
      # first node
      peer_store.add_node(nodes[0])
      expect(peer_store.find_attempt_peers(2)).to eq [nodes[0]]
      # duplicated node
      peer_store.add_node(nodes[0])
      expect(peer_store.find_attempt_peers(2)).to eq [nodes[0]]
      # second node
      peer_store.add_node(nodes[1])
      expect(peer_store.find_attempt_peers(2)).to eq nodes.take(2)
    end

    it '#add_node_addresses' do
      # add_node_addresses with a non-exits id
      peer_store.add_node_addresses(node_ids[0], addresses.take(1))
      expect(peer_store.get_node_addresses(node_ids[0])).to be_nil
      # add a node
      peer_store.add_node(nodes[0])
      peer_store.add_node_addresses(nodes[0].raw_node_id, addresses.take(1))
      expect(peer_store.get_node_addresses(nodes[0].raw_node_id)).to eq addresses.take(1)
      # should ignore duplicated address
      peer_store.add_node_addresses(nodes[0].raw_node_id, addresses.take(2))
      expect(peer_store.get_node_addresses(nodes[0].raw_node_id).sort).to eq addresses.take(2).sort
    end

    it '#get_node_addresses' do
      expect(peer_store.get_node_addresses(node_ids[0])).to be_nil
    end
  end

end

