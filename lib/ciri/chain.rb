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


require 'forwardable'
require_relative 'chain/header_chain'
require_relative 'chain/block'
require_relative 'chain/header'
require_relative 'chain/transaction'
require_relative 'pow'

module Ciri

  # Chain manipulate logic
  # store via rocksdb
  class Chain

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

    def initialize(store, genesis:, network_id:, evm: nil, byzantium_block: nil, homestead_block: nil)
      @store = store
      @header_chain = HeaderChain.new(store, byzantium_block: byzantium_block, homestead_block: homestead_block)
      @genesis = genesis
      @network_id = network_id
      @evm = evm
      load_or_init_store
    end

    # run block
    def finalize_block(block)
      validate_block(block)
      transition(block)
      #
      # mining
      # POW.mine_pow_nonce(block.header.number, block.header.mining_hash, block.header)

      # update state

      #
      # block.nonce
      # block.mix
      # R[i].gas_used = gas_used(state[i - 1], block.transactions[i]) + R[i - 1].gas_used
      # R[i].logs = logs(state[i - 1], block.transactions[i])
      # R[i].z = z(state[i - 1], block.transactions[i])
      # apply_changes
    end

    def validate_block(block, update_state: false)
      raise InvalidBlockError.new('invalid header') unless @header_chain.valid?(header)
      # valid ommers
      raise InvalidBlockError.new('ommers blocks can not more than 2') if block.ommers.size <= 2
      block.ommers.each do |ommer|
        unless is_kin?(ommer, get_block(block.header.parent_hash), 6)
          raise InvalidBlockError.new("invalid ommer relation")
        end
      end

      # valid transactions and gas
      begin
        results = @evm.transition(block)
      rescue EVM::InvalidTransition => e
        raise InvalidBlockError.new(e.message)
      end

      # verify state, root_state 如何计算，由 DB 计算？
      # 1. parent header root == trie(state[i]) 当前状态的 root 相等, 返回 state[i] otherwise state[0]
      if update_state
        # @evm.apply_changes
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
    def insert_blocks(blocks)
      prev_block = blocks[0]
      blocks[1..-1].each do |block|
        unless block.number == prev_block.number + 1 && block.parent_hash == prev_block.get_hash
          raise InvalidBlockError.new("blocks insert orders not correct")
        end
      end

      blocks.each do |block|
        write_block block
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
