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

    # HeaderChain
    # store headers
    class HeaderChain
      HEAD = 'head'
      GENESIS = 'genesis'
      HEADER_PREFIX = 'h'
      TD_SUFFIX = 't'
      NUM_SUFFIX = 'n'

      attr_reader :store, :byzantium_block, :homestead_block

      def initialize(store, byzantium_block: nil, homestead_block: nil)
        @store = store
        @byzantium_block = byzantium_block
        @homestead_block = homestead_block
      end

      def head
        encoded = store[HEAD]
        encoded && Header.rlp_decode!(encoded)
      end

      def head=(header)
        store[HEAD] = header.rlp_encode!
      end

      def get_header(hash)
        encoded = store[HEADER_PREFIX + hash]
        encoded && Header.rlp_decode!(encoded)
      end

      def get_header_by_number(number)
        hash = get_header_hash_by_number(number)
        hash && get_header(hash)
      end

      def valid?(header)
        # ignore genesis header if there not exist one
        return true if header.number == 0 && get_header_by_number(0).nil?

        parent_header = get_header(header.parent_hash)
        return false unless parent_header
        # check height
        return false unless parent_header.number + 1 == header.number
        # check timestamp
        return false unless parent_header.timestamp < header.timestamp

        # check gas limit range
        parent_gas_limit = parent_header.gas_limit
        gas_limit_max = parent_gas_limit + parent_gas_limit / 1024
        gas_limit_min = parent_gas_limit - parent_gas_limit / 1024
        gas_limit = header.gas_limit
        return false unless gas_limit >= 5000 && gas_limit > gas_limit_min && gas_limit < gas_limit_max
        return false unless calculate_difficulty(header, parent_header) == header.difficulty

        # check pow
        begin
          POW.check_pow(header.number, header.mining_hash, header.mix_hash, header.nonce, header.difficulty)
        rescue POW::InvalidError
          return false
        end

        true
      end

      # calculate header difficulty
      # you can find explain in Ethereum yellow paper: Block Header Validity section.
      def calculate_difficulty(header, parent_header)
        return header.difficulty if header.number == 0

        x = parent_header.difficulty / 2048
        y = header.ommers_hash == Utils::BLANK_SHA3 ? 1 : 2

        # handle byzantium fork
        # https://github.com/ethereum/EIPs/blob/181867ae830df5419eb9982d2a24797b2dcad28f/EIPS/eip-609.md
        # https://github.com/ethereum/EIPs/blob/984cf5de90bbf5fbe7e49be227b0c2f9567e661e/EIPS/eip-100.md
        byzantium_fork = byzantium_block && header.number > byzantium_block
        # https://github.com/ethereum/EIPs/blob/984cf5de90bbf5fbe7e49be227b0c2f9567e661e/EIPS/eip-2.md
        homestead_fork = homestead_block && header.number > homestead_block

        time_factor = if byzantium_fork
                        [y - (header.timestamp - parent_header.timestamp) / 9, -99].max
                      elsif homestead_fork
                        [1 - (header.timestamp - parent_header.timestamp) / 10, -99].max
                      else
                        (header.timestamp - parent_header.timestamp) < 13 ? 1 : -1
                      end

        # difficulty bomb
        height = byzantium_fork ? [(header.number - 3000000), 0].max : header.number
        height_factor = 2 ** (height / 100000 - 2)

        difficulty = (parent_header.difficulty + x * time_factor + height_factor).to_i
        [header.difficulty, difficulty].max
      end

      # write header
      def write(header)
        hash = header.get_hash
        # get total difficulty
        td = if header.number == 0
               header.difficulty
             else
               parent_header = get_header(header.parent_hash)
               raise "can't find parent from db" unless parent_header
               parent_td = total_difficulty(parent_header.get_hash)
               parent_td + header.difficulty
             end
        # write header and td
        store.batch do |b|
          b.put(HEADER_PREFIX + hash, header.rlp_encode!)
          b.put(HEADER_PREFIX + hash + TD_SUFFIX, RLP.encode(td, Integer))
        end
      end

      def write_header_hash_number(header_hash, number)
        enc_number = Utils.big_endian_encode number
        store[HEADER_PREFIX + enc_number + NUM_SUFFIX] = header_hash
      end

      def get_header_hash_by_number(number)
        enc_number = Utils.big_endian_encode number
        store[HEADER_PREFIX + enc_number + NUM_SUFFIX]
      end

      def total_difficulty(header_hash = head.nil? ? nil : head.get_hash)
        return 0 if header_hash.nil?
        RLP.decode(store[HEADER_PREFIX + header_hash + TD_SUFFIX], Integer)
      end
    end

    extend Forwardable

    BODY_PREFIX = 'b'

    def_delegators :@header_chain, :head, :total_difficulty, :get_header_by_number, :get_header

    attr_reader :genesis, :network_id, :store, :header_chain

    def initialize(store, genesis:, network_id:, byzantium_block: nil, homestead_block: nil)
      @store = store
      @header_chain = HeaderChain.new(store, byzantium_block: byzantium_block, homestead_block: homestead_block)
      @genesis = genesis
      @network_id = network_id
      load_or_init_store
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
      encoded && Block.rlp_decode!(encoded)
    end

    def write_block(block)
      # write header
      header = block.header
      raise InvalidHeaderError.new("invalid header: #{header.number}") unless @header_chain.valid?(header)
      @header_chain.write(header)

      # write body
      store[BODY_PREFIX + header.get_hash] = block.rlp_encode!

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
