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

require 'spec_helper'
require 'ciri/utils/kv_store'
require 'ciri/chain'
require 'ciri/utils'

RSpec.describe Ciri::Chain do
  let(:tmp_dir) {Dir.mktmpdir}
  let(:store) {Ciri::Utils::KVStore.new(tmp_dir)}

  after do
    store.close
    FileUtils.remove_entry tmp_dir
  end

  context Ciri::Chain::HeaderChain do
    let(:header_chain) {Ciri::Chain::HeaderChain.new(store)}
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

  context Ciri::Chain do
    let(:blocks) do
      load_blocks('blocks')
    end

    let(:chain) {Ciri::Chain.new(store, genesis: blocks[0], network_id: 0)}

    it 'genesis is current block' do
      expect(chain.genesis_hash).to eq chain.current_block.header.get_hash
    end

    it 'insert wrong order blocks' do
      expect do
        chain.insert_blocks(blocks[1..2].reverse)
      end.to raise_error Ciri::Chain::InvalidBlockError
    end

    it 'insert blocks' do
      chain.insert_blocks(blocks[1..2])

      expect(chain.get_block_by_number(1)).to eq blocks[1]
      expect(chain.get_block_by_number(2)).to eq blocks[2]
      expect(chain.current_block).to eq blocks[2]
    end
  end

end
