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
require 'ciri/db/backend/memory'
require 'ciri/pow_chain/chain'
require 'ciri/utils'

RSpec.describe Ciri::POWChain::Chain do
  let(:store) {Ciri::DB::Backend::Memory.new}
  let(:fork_config) {Ciri::Forks::Config.new([[0, Ciri::Forks::Frontier::Schema.new]])}

  context Ciri::POWChain::HeaderChain do
    let(:header_chain) {Ciri::POWChain::HeaderChain.new(store, fork_config: fork_config)}
    let(:headers) do
      load_blocks('blocks').map(&:header)
    end

    it 'get/set head' do
      header_chain.head = headers[0]
      expect(header_chain.head).to eq headers[0]
    end

    it 'write and get' do
      header_chain.write headers[0]
      header_chain.write headers[1]

      expect(header_chain.get_header(headers[0].get_hash)).to eq headers[0]
      expect(header_chain.get_header(headers[1].get_hash)).to eq headers[1]

      # also write total difficulty
      expect(header_chain.total_difficulty(headers[0].get_hash)).to eq headers[0].difficulty
      expect(header_chain.total_difficulty(headers[1].get_hash)).to eq headers[0].difficulty + headers[1].difficulty
    end

    it 'write and get number' do
      header_chain.write_header_hash_number headers[0].get_hash, 0
      header_chain.write_header_hash_number headers[1].get_hash, 1

      expect(header_chain.get_header_hash_by_number(0)).to eq headers[0].get_hash
      expect(header_chain.get_header_hash_by_number(1)).to eq headers[1].get_hash
    end

    it 'valid?' do
      # fail, cause no parent exist
      expect(header_chain.valid? headers[1]).to be_falsey

      # timestamp not correct
      header = headers[1].dup
      header.timestamp = headers[0].timestamp
      expect(header_chain.valid? header).to be_falsey

      # height not correct
      header = headers[1].dup
      header.number += 1
      expect(header_chain.valid? header).to be_falsey

      # gas limit not correct
      header = headers[1].dup
      header.gas_limit = 5001
      expect(header_chain.valid? header).to be_falsey

      # pass valid!
      header_chain.write headers[0]
      expect(header_chain.valid? headers[1]).to be_truthy
    end
  end

  context Ciri::POWChain::Chain do
    let(:blocks) do
      load_blocks('blocks')
    end

    let(:chain) {Ciri::POWChain::Chain.new(store, genesis: blocks[0], network_id: 0, fork_config: fork_config)}

    it 'genesis is current block' do
      expect(chain.genesis_hash).to eq chain.current_block.header.get_hash
    end

    it 'insert wrong order blocks' do
      expect do
        chain.insert_blocks(blocks[1..2].reverse)
      end.to raise_error Ciri::POWChain::Chain::InvalidBlockError
    end

    it 'insert blocks' do
      chain.insert_blocks(blocks[1..2], validate: false)

      expect(chain.get_block_by_number(1)).to eq blocks[1]
      expect(chain.get_block_by_number(2)).to eq blocks[2]
      expect(chain.current_block).to eq blocks[2]
    end

    context 'when forked chain beyond main chain' do
      let(:main_chain_blocks) do
        load_blocks('chain_fork/main_chain')
      end

      let(:forked_chain_blocks) do
        load_blocks('chain_fork/forked_chain')
      end

      let(:chain) {Ciri::POWChain::Chain.new(store, genesis: main_chain_blocks[0], network_id: 0, fork_config: fork_config)}

      it 'forked blocks should reorg current chain' do
        # initial main chain
        chain.insert_blocks(main_chain_blocks[1..-1], validate: false)

        td = chain.total_difficulty
        current_block = chain.current_block

        expect(current_block).to eq main_chain_blocks.last
        chain.current_block.number.times do |i|
          expect(chain.get_block_by_number(i)).to eq main_chain_blocks[i]
        end

        # receive forked chain
        chain.insert_blocks(forked_chain_blocks[1..-1], validate: false)

        expect(chain.total_difficulty).to be > td
        expect(chain.current_block).to_not eq current_block
        expect(chain.current_block).to eq forked_chain_blocks.last

        chain.current_block.number.times do |i|
          expect(chain.get_block_by_number(i)).to eq forked_chain_blocks[i]
        end
      end

    end
  end

end
