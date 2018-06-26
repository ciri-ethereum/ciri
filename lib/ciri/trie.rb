# frozen_string_literal: true

# Copyright (c) 2018, by Jiang Jinyang. <https://justjjy.com>
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


require 'ciri/utils'
require 'ciri/rlp'
require_relative 'trie/nodes'

module Ciri
  # copy py-trie implementation https://github.com/ethereum/py-trie/
  class Trie

    class BadProofError < StandardError
    end

    class << self
      def proof(root_hash, key, proofs)
        proof_nodes = proofs.map {|n| n.is_a?(Trie::Node) ? n : Trie::Node.decode(n)}
        proof_with_nodes(root_hash, key, proof_nodes)
      end

      def proof_with_nodes(root_hash, key, proof_nodes)
        trie = new
        proof_nodes.each do |node|
          trie.persist_node(node)
        end
        trie.root_hash = root_hash
        begin
          result = trie.fetch(key)
        rescue KeyError => e
          raise BadProofError.new("missing proof with hash #{e.message}")
        end
        result
      end
    end

    include Nodes

    attr_accessor :root_hash

    def initialize(db: {}, root_hash: BLANK_NODE_HASH, prune: false)
      @db = db
      @root_hash = root_hash
      @prune = prune
    end

    def put(key, value, node: root_node)
      trie_key = Nibbles.bytes_to_nibbles(key)
      new_node = put_without_update_root_node(trie_key, value, node: node)
      update_root_node(new_node)
      new_node
    end

    def []=(key, value)
      put(key, value)
    end

    def get(trie_key, node: root_node)
      trie_key = Nibbles.bytes_to_nibbles(trie_key) if trie_key.is_a?(String)
      case node
      when NullNode
        NullNode::NULL.to_s
      when Leaf
        trie_key == node.extract_key ? node.value : NullNode::NULL.to_s
      when Extension
        if trie_key[0...node.extract_key.size] == node.extract_key
          sub_node = get_node(node.node_hash)
          get(trie_key[node.extract_key.size..-1], node: sub_node)
        else
          NullNode::NULL.to_s
        end
      when Branch
        if trie_key.empty?
          node.value
        else
          sub_node = get_node(node[trie_key[0]])
          get(trie_key[1..-1], node: sub_node)
        end
      else
        raise "unknown node type #{node}"
      end
    end

    def fetch(trie_key)
      result = get(trie_key)
      raise KeyError.new("key not found: #{trie_key}") if result.nil?
      result
    end

    def [](key)
      get(key)
    rescue KeyError
      nil
    end

    def exists?(key)
      get(key) != NullNode::NULL
    end

    alias include? exists?

    def delete(key, node: root_node)
      trie_key = Nibbles.bytes_to_nibbles(key)
      new_node = delete_without_update_root_node(trie_key, node: node)
      update_root_node(new_node)
      new_node
    end

    def get_node(node_hash, raw: false)
      if node_hash == BLANK_NODE_HASH
        return NullNode::NULL
      elsif node_hash == NullNode::NULL
        return NullNode::NULL
      end
      if node_hash.size < 32
        encoded_node = node_hash
      else
        encoded_node = @db.fetch(node_hash)
      end
      Node.decode(encoded_node)
    end

    def root_node
      get_node(@root_hash)
    end

    def root_node=(value)
      update_root_node(value)
    end

    def persist_node(node)
      key, value = node_to_db_mapping(node)
      if value
        @db[key] = value
      end
      key
    end

    private

    def put_without_update_root_node(trie_key, value, node:)
      prune_node(node)
      case node
      when NullNode
        key = Node.compute_leaf_key(trie_key)
        Leaf.new(key, value)
      when Leaf, Extension
        current_key = node.extract_key
        common_prefix, current_key_remainder, trie_key_remainder = Node.consume_common_prefix(
          current_key,
          trie_key,
        )

        if current_key_remainder.empty? && trie_key_remainder.empty?
          # put value to current leaf or extension
          if node.is_a?(Leaf)
            return Leaf.new(node.key, value)
          else
            sub_node = get_node(node.node_hash)
            new_node = put_without_update_root_node(trie_key_remainder, value, node: sub_node)
          end
        elsif current_key_remainder.empty?
          # put value to new sub_node
          if node.is_a?(Extension)
            sub_node = get_node(node.node_hash)
            new_node = put_without_update_root_node(trie_key_remainder, value, node: sub_node)
          else
            subnode_position = trie_key_remainder[0]
            subnode_key = Node.compute_leaf_key(trie_key_remainder[1..-1])
            sub_node = Leaf.new(subnode_key, value)
            # new leaf
            new_node = Branch.new_with_value(value: node.value)
            new_node[subnode_position] = persist_node(sub_node)
            new_node
          end
        else
          new_node = Branch.new
          if current_key_remainder.size == 1 && node.is_a?(Extension)
            new_node[current_key_remainder[0]] = node.node_hash
          else
            sub_node = if node.is_a?(Extension)
                         key = Node.compute_extension_key(current_key_remainder[1..-1])
                         Extension.new(key, node.node_hash)
                       else
                         key = Node.compute_leaf_key(current_key_remainder[1..-1])
                         Leaf.new(key, node.value)
                       end
            new_node[current_key_remainder[0]] = persist_node(sub_node)
          end

          if !trie_key_remainder.empty?
            sub_node = Leaf.new(Node.compute_leaf_key(trie_key_remainder[1..-1]), value)
            new_node[trie_key_remainder[0]] = persist_node(sub_node)
          else
            new_node[-1] = value
          end
          new_node
        end

        if common_prefix.size > 0
          Extension.new(Node.compute_extension_key(common_prefix), persist_node(new_node))
        else
          new_node
        end
      when Branch
        if !trie_key.empty?
          sub_node = get_node(node[trie_key[0]])
          new_node = put_without_update_root_node(trie_key[1..-1], value, node: sub_node)
          node[trie_key[0]] = persist_node(new_node)
        else
          node[-1] = value
        end
        node
      else
        raise "unknown node type #{node}"
      end
    end

    def delete_without_update_root_node(trie_key, node:)
      prune_node(node)
      case node
      when NullNode
        NullNode::NULL
      when Leaf, Extension
        delete_kv_node(node, trie_key)
      when Branch
        delete_branch_node(node, trie_key)
      else
        raise "unknown node type #{node}"
      end
    end

    def update_root_node(root_node)
      if @prune
        old_root_hash = @root_hash
        if old_root_hash != BLANK_NODE_HASH && @db.include?(old_root_hash)
          @db.delete(old_root_hash)
        end
      end

      if root_node.null?
        @root_hash = BLANK_NODE_HASH
      else
        encoded_root_node = RLP.encode_simple(root_node)
        new_root_hash = Utils.sha3(encoded_root_node)
        @db[new_root_hash] = encoded_root_node
        @root_hash = new_root_hash
      end
    end

    def node_to_db_mapping(node)
      return [node, nil] if node.null?
      encoded_node = RLP.encode_simple(node)
      return [node, nil] if encoded_node.size < 32
      encoded_node_hash = Utils.sha3(encoded_node)
      [encoded_node_hash, encoded_node]
    end

    def prune_node(node)
      if @prune
        key, value = node_to_db_mapping node
        @db.delete(key) if value
      end
    end

    def normalize_branch_node(node)
      sub_nodes = node[0..15].map {|n| get_node(n)}
      return node if sub_nodes.select {|n| !n.null?}.size > 1
      unless node.value.empty?
        return Leaf.new(compute_leaf_key([]), node.value)
      end
      sub_node, sub_node_idx = sub_nodes.each_with_index.find {|v, i| v && !v.null?}
      prune_node(sub_node)

      case sub_node
      when Leaf, Extension
        new_subnode_key = Nibbles.encode_nibbles([sub_node_idx] + Nibbles.decode_nibbles(sub_node.key))
        sub_node.is_a?(Leaf) ? Leaf.new(new_subnode_key, sub_node.value) : Extension.new(new_subnode_key, sub_node.node_hash)
      when Branch
        subnode_hash = persist_node(sub_node)
        Extension.new(Nibbles.encode_nibbles([sub_node_idx]), subnode_hash)
      else
        raise "unknown sub_node type #{sub_node}"
      end
    end

    def delete_branch_node(node, trie_key)
      if trie_key.empty?
        node[-1] = NullNode::NULL
        return normalize_branch_node(node)
      end
      node_to_delete = get_node(node[trie_key[0]])
      sub_node = delete_without_update_root_node(trie_key[1..-1], node: node_to_delete)
      encoded_sub_node = persist_node(sub_node)
      return node if encoded_sub_node == node[trie_key[0]]

      node[trie_key[0]] = encoded_sub_node
      return normalize_branch_node(node) if encoded_sub_node == NullNode::NULL

      node
    end

    def delete_kv_node(node, trie_key)
      current_key = node.extract_key
      # key not exists
      return node if trie_key[0...current_key.size] != current_key
      if node.is_a?(Leaf)
        if trie_key == current_key
          return NullNode::NULL
        else
          return node
        end
      end

      sub_node_key = trie_key[current_key.size..-1]
      sub_node = get_node(node.node_hash)

      new_sub_node = delete_without_update_root_node(sub_node_key, node: sub_node)
      encoded_new_sub_node = persist_node(new_sub_node)

      return node if encoded_new_sub_node == node.node_hash

      return NullNode::NULL if new_sub_node.null?

      if new_sub_node.is_a?(Leaf) || new_sub_node.is_a?(Extension)
        prune_node(new_sub_node)
        new_key = Nibbles.encode_nibbles(current_key + Nibbles.decode_nibbles(new_sub_node.key))
        if new_sub_node.is_a?(Leaf)
          return Leaf.new(new_key, new_sub_node.value)
        else
          return Extension.new(new_key, new_sub_node.node_hash)
        end
      end

      if new_sub_node.is_a?(Branch)
        return Extension.new(Nibbles.encode_nibbles(current_key), encoded_new_sub_node)
      end

      raise "can't correct delete kv node"
    end

  end
end