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


require 'forwardable'
require 'ciri/core_ext'
require 'ciri/state'
require 'ciri/utils/logger'
require 'ciri/shasper/constants'
require_relative 'errors'

using Ciri::CoreExt

module Ciri
  module BeaconChain

    # Chain manipulate logic
    # store via rocksdb
    class Chain
      include Shasper::Constants
      include Ciri::Utils::Logger

      extend Forwardable

      HEAD = 'head'.b
      GENESIS = 'genesis'.b
      BODY_PREFIX = 'b'.b
      NUMBER_SUFFIX = 'n'.b

      attr_reader :store, :genesis

      def initialize(store, genesis:)
        @store = store
        @genesis = genesis
        load_or_init_store
      end

      # run block
      def import_block(block, validate: true)
        debug("import block #{block.header.number}")
        validate_block(block) if validate
        write_block(block)
      end

      # validate block, effect current state
      def validate_block(block)
        # check block ready conditions
        # 1. parent block must already be accepted.
        parent_block = get_block(block.parent_hash)
        raise BlockNotReadyError.new("can't find parent block by hash #{block.parent_hash.to_hex}") unless parent_block
        # TODO 2. pow_chain_ref block must already be accepted.
        # 3. local time must greater or equal than minimum timestamp.
        unless (local_timestamp = Time.now.to_i) >= (minimum_timestamp = genesis_time + block.slot_number * SLOT_DURATION)
          raise BlockNotReadyError.new("local_timestamp(#{local_timestamp}) must greater than or equal with minimum_timestamp(#{minimum_timestamp})")
        end
      end

      # insert blocks in order
      # blocks must be ordered from lower height to higher height
      def insert_blocks(blocks, validate: true)
        prev_block = blocks[0]
        blocks[1..-1].each do |block|
          unless block.number == prev_block.number + 1 && block.parent_hash == prev_block.get_hash
            raise InvalidBlockError.new("blocks insert orders not correct")
          end
        end

        blocks.each do |block|
          import_block(block, validate: validate)
        end
      end

      def head
        encoded = store[HEAD]
        encoded && Block.rlp_decode(encoded)
      end

      alias current_block head

      def set_head(block, encoded: Block.rlp_encode(block))
        store[HEAD] = encoded
      end

      def get_block(hash)
        encoded = store[BODY_PREFIX + hash]
        encoded && Block.rlp_decode(encoded)
      end

      def write_block(block)
        encoded = Block.rlp_encode(block)
        store[BODY_PREFIX + block.get_hash] = encoded

        if fork_choice?(block)
          reorg_chain(block, current_block)
        else
          set_head(encoded: encoded)
        end
      end

      private

      def fork_choice?(block)
        # TODO Beacon chain fork choice rule https://notes.ethereum.org/SCIg8AH5SA-O4C1G1LYZHQ#
        false
      end

      # reorg chain
      def reorg_chain(new_block, old_block)
        # TODO Beacon chain fork choice rule https://notes.ethereum.org/SCIg8AH5SA-O4C1G1LYZHQ#
        nil
        # new_chain = []
        # # find common ancestor block
        # # move new_block and old_block to same height
        # while new_block.number > old_block.number
        #   new_chain << new_block
        #   new_block = get_block(new_block.parent_hash)
        # end
        #
        # while old_block.number > new_block.number
        #   old_block = get_block(old_block.parent_hash)
        # end
        #
        # while old_block.get_hash != new_block.get_hash
        #   new_chain << new_block
        #   old_block = get_block(old_block.parent_hash)
        #   new_block = get_block(new_block.parent_hash)
        # end
        #
        # # rewrite chain
        # new_chain.reverse_each {|block| rewrite_block(block)}
      end

      def genesis_time
        # TODO get genesis block timestamp
        0
      end

      def load_or_init_store
        if @genesis.nil?
          warn "BeaconChain GENESIS block is nil!!!"
          return
        end
        # write genesis block
        if get_block(@genesis.get_hash).nil?
          encoded = Block.rlp_encode(@genesis)
          store[GENESIS] = encoded
          write_block(@genesis)
        end
      end

    end
  end
end
