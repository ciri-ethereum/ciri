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
require 'ciri/chain'
require 'ciri/evm'
require 'ciri/evm/state'
require 'ciri/types/account'
require 'ciri/forks/frontier'
require 'ciri/utils'
require 'ciri/db/backend/memory'
require 'ciri/chain/transaction'
require 'ciri/key'

RSpec.describe Ciri::Chain do

  before(:all) do
    prepare_ethereum_fixtures
  end

  parse_account = proc do |address, v|
    balance = Ciri::Utils.hex_to_number(v["balance"])
    nonce = Ciri::Utils.hex_to_number(v["nonce"])
    code = Ciri::Utils.to_bytes(v["code"])
    storage = v["storage"].map do |k, v|
      [Ciri::Utils.to_bytes(k), Ciri::Utils.to_bytes(v).rjust(32, "\x00".b)]
    end.to_h
    [Ciri::Types::Account.new(balance: balance, nonce: nonce), code, storage]
  end

  parse_header = proc do |data|
    columns = {}
    columns[:logs_bloom] = Ciri::Utils.to_bytes(data['bloom'])
    columns[:beneficiary] = Ciri::Utils.to_bytes(data['coinbase'])
    columns[:difficulty] = Ciri::Utils.hex_to_number(data['difficulty'])
    columns[:extra_data] = Ciri::Utils.to_bytes(data['extraData'])
    columns[:gas_limit] = Ciri::Utils.hex_to_number(data['gasLimit'])
    columns[:gas_used] = Ciri::Utils.hex_to_number(data['gasUsed'])
    columns[:mix_hash] = Ciri::Utils.to_bytes(data['mixHash'])
    columns[:nonce] = Ciri::Utils.to_bytes(data['nonce'])
    columns[:number] = Ciri::Utils.hex_to_number(data['number'])
    columns[:parent_hash] = Ciri::Utils.to_bytes(data['parentHash'])
    columns[:receipts_root] = Ciri::Utils.to_bytes(data['receiptTrie'])
    columns[:state_root] = Ciri::Utils.to_bytes(data['stateRoot'])
    columns[:transactions_root] = Ciri::Utils.to_bytes(data['transactionsTrie'])
    columns[:timestamp] = Ciri::Utils.hex_to_number(data['timestamp'])
    columns[:ommers_hash] = Ciri::Utils.to_bytes(data['uncleHash'])

    header = Ciri::Chain::Header.new(**columns)
    unless Ciri::Utils.to_hex(header.get_hash) == data['hash']
      p columns
      # raise "expect header #{Ciri::Utils.to_hex(header.get_hash)} shoult equal to #{data['hash']}"
    end
    header
  end

  run_test_case = proc do |test_case, prefix: nil, tags: {}|
    test_case.each do |name, t|
      tags2 = tags.dup

      # TODO only run Frontier test for now
      next unless name.include?("Frontier")

      it "#{prefix} #{name}", **tags2 do
        db = Ciri::DB::Backend::Memory.new
        state = Ciri::EVM::State.new(db)
        # pre
        t['pre'].each do |address, v|
          address = Ciri::Types::Address.new Ciri::Utils.to_bytes(address)

          account, code, storage = parse_account[address, v]
          state.set_balance(address, account.balance)
          state.set_nonce(address, account.nonce)
          state.set_account_code(address, code)

          storage.each do |key, value|
            state.store(address, key, value)
          end
        end

        genesis = if t['genesisRLP']
                    Ciri::Chain::Block.rlp_decode(Ciri::Utils.to_bytes t['genesisRLP'])
                  elsif t['genesisBlockHeader']
                    Ciri::Chain::Block.new(header: parse_header[t['genesisBlockHeader']], transactions: [], ommers: [])
                  end

        chain = Ciri::Chain.new(db, genesis: genesis, network_id: 0)

        # run block
        t['blocks'].each do |b|
          begin
            block = Ciri::Chain::Block.rlp_decode Ciri::Utils.to_bytes(b['rlp'])
            chain.import_block(block)
          rescue Ciri::Chain::InvalidBlockError, Ciri::RLP::InvalidValueError => e
            p e
            expect(b['blockHeader']).to be_nil
            expect(b['transactions']).to be_nil
            expect(b['uncleHeaders']).to be_nil
            break
          end

          # check status
          block = chain.get_block(block.get_hash)

          if b['blockHeader']
            expect(block.header).to eq fixture_to_block_header(b['blockHeader'])
          end

          if b['transactions']
            expect(block.transactions).to eq b['transactions'].map {|t| fixture_to_transaction(t)}
          end

          if b['uncleHeaders']
            expect(block.ommers).to eq b['uncleHeaders'].map {|h| fixture_to_block_header(h)}
          end

        end
      end

    end
  end

  slow_cases = %w{
  }.map {|f| ["fixtures/BlockchainTests/#{f}", true]}.to_h

  slow_topics = %w{
  }.map {|f| ["fixtures/BlockchainTests/#{f}", true]}.to_h

  white_list_topics = %w{
    bcBlockGasLimitTest
    bcValidBlockTest
    bcForgedTest
    bcInvalidHeaderTest
    bcStateTest
    bcGasPricerTest
  }.map {|f| ["fixtures/BlockchainTests/#{f}", true]}.to_h

  Dir.glob("fixtures/BlockchainTests/*").each do |topic|
    # skip topics
    unless white_list_topics.include? topic
      skip topic
      next
    end

    tags = {}
    # tag slow test topics
    if slow_topics.include?(topic)
      tags[:slow_tests] = true
    end

    Dir.glob("#{topic}/**/*.json").each do |t|
      tags = tags.dup
      # tag slow test cases
      if slow_cases.include?(t)
        tags[:slow_tests] = true
      end

      run_test_case[JSON.load(open t), prefix: topic, tags: tags]
    end
  end if true

    # run_test_case[JSON.load(open 'fixtures/BlockchainTests/bcGasPricerTest/RPC_API_Test.json'), prefix: 'test', tags: {}]

end
