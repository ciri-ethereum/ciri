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
require 'ciri/core_ext'
require 'ciri/pow_chain/chain'
require 'ciri/evm'
require 'ciri/state'
require 'ciri/types/account'
require 'ciri/forks/frontier'
require 'ciri/utils'
require 'ciri/db/backend/memory'
require 'ciri/key'

using Ciri::CoreExt

KNOWN_FAILED_CASE = [
  "ShanghaiLove_Homestead",
  "DelegateCallSpam_Homestead"
]

SLOW_TOPIC = [
  "fixtures/BlockchainTests/bcExploitTest",
  "fixtures/BlockchainTests/bcWalletTest"
]

RSpec.describe Ciri::POWChain::Chain do

  include Ciri::Utils::Logger

  before(:all) do
    prepare_ethereum_fixtures
  end

  def self.run_test_case(test_case, prefix: nil, tags: )
    test_case.each do |name, t|

      # TODO support all forks
      next skip("#{prefix} #{name}") if name.include?("Constantinople")

      if KNOWN_FAILED_CASE.include?(name)
        skip "#{name} still fail, need invesgate"
        break
      end

      # register rspec test case
      it "#{prefix} #{name}", **tags do
        db = Ciri::DB::Backend::Memory.new
        state = Ciri::State.new(db)
        # pre
        prepare_state(state, t)

        genesis = if t['genesisRLP']
                    Ciri::POWChain::Block.rlp_decode(t['genesisRLP'].decode_hex)
                  elsif t['genesisBlockHeader']
                    Ciri::POWChain::Block.new(header: parse_header(t['genesisBlockHeader']), transactions: [], ommers: [])
                  end

        fork_config = extract_fork_config(t)
        chain = Ciri::POWChain::Chain.new(db, genesis: genesis, network_id: 0, fork_config: fork_config)

        # run block
        t['blocks'].each do |b|
          begin
            block = Ciri::POWChain::Block.rlp_decode b['rlp'].decode_hex
            chain.import_block(block)
          rescue Ciri::POWChain::Chain::InvalidBlockError,
              Ciri::RLP::InvalidError,
              Ciri::EVM::Error,
              Ciri::Types::Errors::InvalidError => e
            error e
            expect(b['blockHeader']).to be_nil
            expect(b['transactions']).to be_nil
            expect(b['uncleHeaders']).to be_nil
            break
          end

          # check status
          block = chain.get_block(block.get_hash)
          expect(block.header).to eq fixture_to_block_header(b['blockHeader']) if b['blockHeader']
          expect(block.transactions).to eq b['transactions'].map {|t| fixture_to_transaction(t)} if b['transactions']
          expect(block.ommers).to eq b['uncleHeaders'].map {|h| fixture_to_block_header(h)} if b['uncleHeaders']

        end
      end

    end
  end

  Dir.glob("fixtures/BlockchainTests/**").each do |topic|
    tags = SLOW_TOPIC.include?(topic) ? {slow: true} : {}
    Dir.glob("#{topic}/*.json").each do |t|
      run_test_case(JSON.load(open t), prefix: topic, tags: tags)
    end
  end
end

