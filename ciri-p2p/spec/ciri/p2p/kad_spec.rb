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
require 'ciri/p2p/kad'
require 'ciri/core_ext'

using Ciri::CoreExt

RSpec.describe Ciri::P2P::Kad do
  describe Ciri::P2P::Kad::Node do
    let(:pubkey1) {10.encode_big_endian.pad_zero(65)}
    let(:pubkey2) {11.encode_big_endian.pad_zero(65)}
    let(:pubkey3) {12.encode_big_endian.pad_zero(65)}

    it '#distance_to' do
      node1 = described_class.new(pubkey1)
      node2 = described_class.new(pubkey2)
      distance = node1.distance_to(node2.id)
      expect(distance).to be > 0
      expect(node1.id ^ node2.id).to eq distance
    end

    it '#==' do
      node1 = described_class.new(pubkey1)
      node2 = described_class.new(pubkey2)
      node3 = described_class.new(pubkey1)
      expect(node1).to eq node3
      expect(node1).not_to eq node2
    end

    it '#<=>' do
      node1 = described_class.new(pubkey1)
      node2 = described_class.new(pubkey2)
      node3 = described_class.new(pubkey3)
      expect([node1, node2, node3].sort).to eq [node1, node2, node3].sort_by{|node| node.id}
    end
  end

  describe Ciri::P2P::Kad::KBucket do
    let(:pubkey1) {10.encode_big_endian.pad_zero(65)}
    let(:pubkey2) {11.encode_big_endian.pad_zero(65)}
    let(:pubkey3) {12.encode_big_endian.pad_zero(65)}
    let(:pubkey4) {13.encode_big_endian.pad_zero(65)}
    let(:node1) {Ciri::P2P::Kad::Node.new(pubkey1)}
    let(:node2) {Ciri::P2P::Kad::Node.new(pubkey2)}
    let(:node3) {Ciri::P2P::Kad::Node.new(pubkey3)}
    let(:node4) {Ciri::P2P::Kad::Node.new(pubkey4)}
    let(:bucket) {described_class.new(start_id: 0, end_id: Ciri::P2P::Kad::K_MAX_NODE_ID)}
    let(:fake_node_class) do
      Class.new(Ciri::P2P::Kad::Node) do
        attr_reader :id
        def initialize(id)
          @id = id
        end
      end
    end

    it '#distance_to' do
      [node1, node2, node3].each do |node|
        expect(bucket.distance_to(node.id)).to eq bucket.midpoint ^ node.id
      end
    end

    it '#nodes_by_distance_to' do
      nodes = [node1, node2, node3]
      nodes.each {|node| bucket.add(node) }
      expect(bucket.nodes_by_distance_to(node4.id)).to eq nodes.sort_by{|node| node.distance_to node4.id}
    end

    it '#split' do
      bucket = described_class.new(start_id: 0, end_id: 10)
      nodes = (1..7).map{|id| fake_node_class.new(id) }
      nodes.each{|node| bucket.add(node) }
      expect(nodes.size).to eq 7
      lower, upper = bucket.split
      expect(lower.size).to eq 5
      expect(lower.nodes.sort).to eq nodes[0...5].sort
      expect(upper.size).to eq 2
      expect(upper.nodes.sort).to eq nodes[5...7].sort
    end

    it '#delete' do
      nodes = [node1, node2, node3]
      nodes.each {|node| bucket.add(node) }
      expect(bucket.size).to eq 3
      bucket.delete(node1)
      expect(bucket.size).to eq 2
      expect(bucket.nodes.sort).to eq nodes[1..2].sort
    end

    it '#cover?' do
      bucket = described_class.new(start_id: 0, end_id: 10)
      expect(bucket.cover?(fake_node_class.new(1))).to be true
      expect(bucket.cover?(fake_node_class.new(5))).to be true
      expect(bucket.cover?(fake_node_class.new(10))).to be true
      expect(bucket.cover?(fake_node_class.new(11))).to be false
    end

    it '#full?' do
      bucket = described_class.new(start_id: 0, end_id: 10, k_size: 4)
      bucket.add(node1)
      expect(bucket.full?).to be false
      bucket.add(node2)
      expect(bucket.full?).to be false
      bucket.add(node3)
      expect(bucket.full?).to be false
      bucket.add(node4)
      expect(bucket.full?).to be true
    end

    it '#include?' do
      nodes = [node1, node2, node3]
      nodes.each do |node|
        expect(bucket.cover?(node)).to be true
        expect(bucket.include?(node)).to be false
        bucket.add(node)
        expect(bucket.include?(node)).to be true
      end
    end
  end

  describe Ciri::P2P::Kad::RoutingTable do
    let(:local_node) { Ciri::P2P::Kad::Node.new(1024.encode_big_endian.pad_zero(65)) }
    let(:nodes) do 
      1000.times.map{|i| Ciri::P2P::Kad::Node.new(i.encode_big_endian.pad_zero(65)) } 
    end
    let(:table) do 
      table = described_class.new(local_node: local_node)
      nodes.each{ |node| table.add_node(node) }
      table
    end

    it "#get_random_nodes" do
      expect(table.get_random_nodes(100).count).to eq 100
      expect(table.get_random_nodes(2000).count).to eq table.size
    end

    it "#idle_buckets" do
      expect(table.idle_buckets.size).to eq 0
      allow(table.buckets[0]).to receive(:last_updated).and_return(Time.now.to_i - 10000)
      expect(table.idle_buckets.size).to eq 1
    end

    it "#not_full_buckets" do
      # we must have some nodes not full
      expect(table.buckets.size).to be > (table.size / 16)
      expect(table.not_full_buckets.size).to be < table.buckets.size
    end

    it "#delete_node" do
      table_size = table.size
      node = table.get_random_nodes(1)[0]
      expect(table.include?(node)).to be true
      table.delete_node(node)
      expect(table.size + 1).to eq table_size
      expect(table.include?(node)).to be false
    end

    it '#buckets_by_distance_to' do
      expect(table.buckets_by_distance_to(42)).to eq table.buckets.sort_by{|bucket| bucket.distance_to(42)}
    end

    it "#find_bucket_for_node" do
      node = table.get_random_nodes(1)[0]
      bucket = table.find_bucket_for_node(node)
      expect(bucket.include?(node)).to be true
    end

    it '#find_neighbours' do
      expect(table.find_neighbours(42).size).to be > 0
    end

  end

end

