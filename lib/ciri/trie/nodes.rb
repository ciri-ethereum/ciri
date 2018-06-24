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


require_relative 'nibbles'
require 'forwardable'

module Ciri
  class Trie
    module Nodes

      class InvalidNode < StandardError
      end

      class Node
        def null?
          false
        end

        def branch?
          false
        end

        class << self
          def decode(hash_or_encoded)
            if hash_or_encoded == BLANK_NODE_HASH || hash_or_encoded == Utils::BLANK_SHA3 || hash_or_encoded == ''.b
              return NullNode::NULL
            end
            decoded = hash_or_encoded.is_a?(String) ? RLP.decode(hash_or_encoded) : hash_or_encoded
            if decoded == ''.b
              NullNode::NULL
            elsif decoded.size == 2
              key, value = decoded
              nibbles = Nibbles.decode_nibbles(key)
              if Nibbles.is_nibbles_terminated?(nibbles)
                Leaf.new(key, value)
              else
                Extension.new(key, value)
              end
            elsif decoded.size == 17
              Branch.new(decoded)
            else
              raise InvalidNode.new("can't determine node type: #{Utils.data_to_hex hash_or_encoded}")
            end
          end

          def compute_leaf_key(nibbles)
            Nibbles.encode_nibbles(Nibbles.add_nibbles_terminator(nibbles))
          end

          def compute_extension_key(nibbles)
            Nibbles.encode_nibbles(nibbles)
          end

          def get_common_prefix_length(left_key, right_key)
            left_key.zip(right_key).each_with_index do |(l_nibble, r_nibble), i|
              return i if l_nibble != r_nibble
            end

            [left_key.size, right_key.size].min
          end

          def consume_common_prefix(left_key, right_key)
            common_prefix_length = get_common_prefix_length(left_key, right_key)
            common_prefix = left_key[0...common_prefix_length]
            left_reminder = left_key[common_prefix_length..-1]
            right_reminder = right_key[common_prefix_length..-1]
            [common_prefix, left_reminder, right_reminder]
          end

        end

      end

      class NullNode < Node

        NULL = NullNode.new

        def initialize
          raise NotImplementedError if @singleton
          @singleton = true
        end

        def null?
          true
        end

        def rlp_encode
          RLP.encode(''.b)
        end
      end

      class Branch < Node

        class << self
          def new_with_value(branches: [NullNode::NULL] * 16, value:)
            new(branches + [value])
          end
        end

        extend Forwardable

        def_delegators :@branches, :[], :[]=, :each, :all?, :any?

        def initialize(branches = [NullNode::NULL] * 16 + [''.b])
          raise InvalidNode.new('branches size should be 17') if branches.size != 17
          @branches = branches
        end

        def value
          self[16]
        end

        def branch?
          true
        end

        def rlp_encode
          RLP.encode_simple(@branches)
        end
      end

      class Extension < Node
        attr_reader :key, :node_hash

        def initialize(key, node_hash)
          @key = key
          @node_hash = node_hash
        end

        def extract_key
          Nibbles.remove_nibbles_terminator(Nibbles.decode_nibbles key)
        end

        def rlp_encode
          RLP.encode_simple([key, node_hash])
        end
      end

      class Leaf < Node

        attr_reader :key, :value

        def initialize(key, value)
          @key = key
          @value = value
        end

        def extract_key
          Nibbles.remove_nibbles_terminator(Nibbles.decode_nibbles key)
        end

        def rlp_encode
          RLP.encode_simple([key, value])
        end
      end

      BLANK_NODE_HASH = Utils.sha3(RLP.encode(''.b)).freeze

    end
  end
end
