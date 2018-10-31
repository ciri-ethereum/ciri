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


require 'ciri/utils/logger'
require 'ciri/utils'
require 'ciri/p2p/node'
require 'forwardable'

module Ciri
  module P2P


    # Kademlia algorithm
    # modified from https://github.com/ethereum/py-evm/blob/master/p2p/kademlia.py
    module Kad
      K_BITS = 8
      K_BUCKET_SIZE = 16
      K_REQUEST_TIMEOUT = 0.9
      K_IDLE_BUCKET_REFRESH_INTERVAL = 3600
      K_PUBKEY_SIZE = 512
      K_ID_SIZE = 256
      K_MAX_NODE_ID = 2 ** K_ID_SIZE - 1

      class Node
        attr_reader :id, :raw_node_id

        def initialize(raw_node_id)
          @raw_node_id = raw_node_id
          @id = Utils.big_endian_decode(Utils.keccak(raw_node_id))
        end

        def distance_to(id)
          @id ^ id
        end

        def ==(other)
          self.class == other.class && self.id == other.id
        end

        def <=>(other)
          @id <=> other.id
        end
      end

      class KBucket

        attr_reader :k_size, :nodes, :start_id, :end_id, :last_updated, :replacement_cache

        def initialize(start_id:, end_id:, k_size: K_BUCKET_SIZE)
          @start_id = start_id
          @end_id = end_id
          @k_size = k_size
          @nodes = []
          @replacement_cache = []
          @last_updated = Time.now.to_i
        end

        # use to compute node distance with kbucket
        def midpoint
          @start_id + (@end_id - @start_id) / 2
        end

        def distance_to(id)
          midpoint ^ id
        end

        # find neighbour nodes
        def nodes_by_distance_to(id)
          @nodes.sort_by do |node|
            node.distance_to(id)
          end
        end

        # split to two kbucket by midpoint
        def split
          split_point = midpoint
          lower = KBucket.new(start_id: @start_id, end_id: split_point)
          upper = KBucket.new(start_id: split_point + 1, end_id: @end_id)
          @nodes.each do |node|
            if node.id <= split_point
              lower.add(node)
            else
              upper.add(node)
            end
          end
          @replacement_cache.each do |node|
            if node.id <= split_point
              lower.replacement_cache << node
            else
              upper.replacement_cache << node
            end
          end
          [lower, upper]
        end

        def delete(node)
          @nodes.delete(node)
        end

        def cover?(node)
          @start_id <= node.id && node.id <= @end_id
        end

        def full?
          @nodes.size == k_size
        end

        # Try add node into bucket
        # if node is exists, it is moved to the tail
        # if the node is node exists and bucket not full, it is added at tail
        # if the bucket is full, node will added to replacement_cache, and return the head of the list, which should be evicted if it failed to respond to a ping.
        def add(node)
          @last_updated = Time.now.to_i
          if @nodes.include?(node)
            @nodes.remove(node)
            @nodes << node
          elsif @nodes.size < k_size
            @nodes << node
          else
            @replacement_cache << node
            return head
          end
          nil
        end

        def head
          @nodes[0]
        end

        def include?(node)
          @nodes.include?(node)
        end

        def size
          @nodes.size
        end
      end

      class RoutingTable
        attr_reader :buckets, :local_node

        def initialize(local_node:)
          @local_node = local_node
          @buckets = [KBucket.new(start_id: 0, end_id: K_MAX_NODE_ID)]
        end

        def get_random_nodes(count)
          count = size if count > size
          nodes = []
          while nodes.size < count
            bucket = @buckets.sample
            next if bucket.nodes.empty?
            node = bucket.nodes.sample
            unless nodes.include?(node)
              nodes << node
            end
          end
          nodes
        end

        def idle_buckets
          bucket_idled_at = Time.now.to_i - K_IDLE_BUCKET_REFRESH_INTERVAL
          @buckets.select do |bucket| 
            bucket.last_updated < bucket_idled_at
          end
        end

        def not_full_buckets
          @buckets.select do |bucket|
            !bucket.full?
          end
        end

        def delete_node(node)
          find_bucket_for_node(node).delete(node)
        end

        def update(raw_node_id)
          add_node(Node.new(raw_node_id))
        end

        def add_node(node)
          raise ArgumentError.new("can't add local_node") if @local_node == node
          bucket = find_bucket_for_node(node)
          eviction_candidate = bucket.add(node)
          # bucket is full, otherwise will return nil
          if eviction_candidate
            depth = compute_shared_prefix_bits(bucket.nodes)
            if bucket.cover?(@local_node) || (depth % K_BITS != 0 && depth != K_ID_SIZE)
              split_bucket(@buckets.index(bucket))
              return add_node(node)
            end
            return eviction_candidate
          end
          nil
        end

        def buckets_by_distance_to(id)
          @buckets.sort_by do |bucket|
            bucket.distance_to(id)
          end
        end

        def include?(node)
          find_bucket_for_node(node).include?(node)
        end

        def size
          @buckets.map(&:size).sum
        end

        def each_node(&blk)
          @buckets.each do |bucket|
            bucket.nodes do |node|
              blk.call(node)
            end
          end
        end

        def find_neighbours(id, k: K_BUCKET_SIZE)
          nodes = []
          buckets_by_distance_to(id).each do |bucket|
            bucket.nodes_by_distance_to(id).each do |node|
              if node.id != id
                nodes << node
                # find 2 * k nodes to avoid edge cases
                break if nodes.size == k * 2
              end
            end
          end
          sort_by_distance(nodes, id)[0...k]
        end

        # do binary search to find node
        def find_bucket_for_node(node)
          @buckets.bsearch do |bucket|
            bucket.end_id >= node.id
          end
        end

        private

        def split_bucket(index)
          bucket = @buckets[index]
          a, b = bucket.split
          @buckets[index] = a
          @buckets.insert(index + 1, b)
        end

        def compute_shared_prefix_bits(nodes)
          return K_ID_SIZE if nodes.size < 2
          bits = nodes.map{|node| to_binary(node.id) }
          (1..K_ID_SIZE).each do |i|
            # check common prefix shared by nodes
            if bits.map{|b| b[0..i]}.uniq.size != 1
              return i - 1
            end
          end
        end

        def sort_by_distance(nodes, target_id)
          nodes.sort_by do |node|
            node.distance_to(target_id)
          end
        end

        def to_binary(x)
          x.to_s(2).b.rjust(K_ID_SIZE, "\x00".b)
        end

      end

    end
  end
end

