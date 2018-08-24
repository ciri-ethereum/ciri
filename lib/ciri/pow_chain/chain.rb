# frozen_string_literal: true

# Copyright 2018 Jiang Jinyang <https://justjjy.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


require 'forwardable'
require 'ciri/evm'
require 'ciri/state'
require 'ciri/utils/logger'
require 'ciri/forks'
require 'ciri/types/receipt'
require_relative 'header_chain'
require_relative 'block'
require_relative 'header'
require_relative 'transaction'
require_relative 'ethash'

module Ciri
  module POWChain

    # Chain manipulate logic
    # store via rocksdb
    class Chain
      include Ciri::Utils::Logger

      class Error < StandardError
      end

      class InvalidHeaderError < Error
      end

      class InvalidBlockError < Error
      end

      extend Forwardable

      BODY_PREFIX = 'b'

      def_delegators :@header_chain, :head, :total_difficulty, :get_header_by_number, :get_header

      attr_reader :genesis, :network_id, :store, :header_chain

      def initialize(store, genesis:, network_id:, fork_config:)
        @store = store
        @header_chain = HeaderChain.new(store, fork_config: fork_config)
        @genesis = genesis
        @network_id = network_id
        @fork_config = fork_config
        load_or_init_store
      end

      # run block
      def import_block(block, validate: true)
        debug("import block #{block.header.number}")
        validate_block(block) if validate
        write_block(block)

        # update state
        # apply_changes
      end

      # validate block, effect current state
      def validate_block(block)
        raise InvalidBlockError.new('invalid header') unless @header_chain.valid?(block.header)
        # valid ommers
        raise InvalidBlockError.new('ommers blocks can not more than 2') if block.ommers.size > 2
        block.ommers.each do |ommer|
          unless is_kin?(ommer, get_block(block.header.parent_hash), 6)
            raise InvalidBlockError.new("invalid ommer relation")
          end
        end

        parent_header = @header_chain.get_header(block.header.parent_hash)
        state = State.new(store, state_root: parent_header.state_root)
        evm = EVM.new(state: state, chain: self, fork_schema: @fork_config.choose_fork(block.header.number))
        # valid transactions and gas
        begin
          receipts = evm.transition(block)
        rescue EVM::InvalidTransition => e
          raise InvalidBlockError.new(e.message)
        end

        # verify state root
        if evm.state_root != block.header.state_root
          error("incorrect state_root, evm: #{Utils.to_hex evm.state_root}, header: #{Utils.to_hex block.header.state_root} height: #{block.header.number}")
          raise InvalidBlockError.new("incorrect state_root")
        end

        # verify receipts root
        trie = Trie.new
        receipts.each_with_index do |r, i|
          trie[RLP.encode(i)] = RLP.encode(r)
        end

        if trie.root_hash != block.header.receipts_root
          raise InvalidBlockError.new("incorrect receipts_root")
        end

        # verify state root
        trie = Trie.new
        block.transactions.each_with_index do |t, i|
          trie[RLP.encode(i)] = RLP.encode(t)
        end

        if trie.root_hash != block.header.transactions_root
          raise InvalidBlockError.new("incorrect transactions_root")
        end
      end

      def genesis_hash
        genesis.header.get_hash
      end

      def current_block
        get_block(head.get_hash)
      end

      def current_height
        head.number
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

      def get_block_by_number(number)
        hash = @header_chain.get_header_hash_by_number(number)
        hash && get_block(hash)
      end

      def get_block(hash)
        encoded = store[BODY_PREFIX + hash]
        encoded && Block.rlp_decode(encoded)
      end

      def write_block(block)
        # write header
        header = block.header
        # raise InvalidHeaderError.new("invalid header: #{header.number}") unless @header_chain.valid?(header)
        @header_chain.write(header)

        # write body
        store[BODY_PREFIX + header.get_hash] = block.rlp_encode

        td = total_difficulty(header.get_hash)

        if td > total_difficulty
          # new block not follow current head, need reorg chain
          if head && ((header.number <= head.number) || (header.number == head.number + 1 && header.parent_hash != head.get_hash))
            reorg_chain(block, current_block)
          else
            # otherwise, new block extend current chain, just update chain head
            @header_chain.head = header
            @header_chain.write_header_hash_number(header.get_hash, header.number)
          end
        end
      end

      private

      def is_kin?(ommer, parent, n)
        return false if parent.nil?
        return false if n == 0
        return true if get_header(ommer.parent_hash) == get_header(parent.header.parent_hash) &&
            ommer != parent.header &&
            !parent.ommers.include?(ommer)
        is_kin?(ommer, get_block(parent.header.parent_hash), n - 1)
      end

      # reorg chain
      def reorg_chain(new_block, old_block)
        new_chain = []
        # find common ancestor block
        # move new_block and old_block to same height
        while new_block.number > old_block.number
          new_chain << new_block
          new_block = get_block(new_block.parent_hash)
        end

        while old_block.number > new_block.number
          old_block = get_block(old_block.parent_hash)
        end

        while old_block.get_hash != new_block.get_hash
          new_chain << new_block
          old_block = get_block(old_block.parent_hash)
          new_block = get_block(new_block.parent_hash)
        end

        # rewrite chain
        new_chain.reverse_each {|block| rewrite_block(block)}
      end

      # rewrite block
      # this method will treat block as canonical chain block
      def rewrite_block(block)
        @header_chain.head = block.header
        @header_chain.write_header_hash_number(block.get_hash, block.number)
      end

      def load_or_init_store
        # write genesis block, is chain head not exists
        if head.nil?
          write_block(genesis)
        end
      end
    end

  end
end
