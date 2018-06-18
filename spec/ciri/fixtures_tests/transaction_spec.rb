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
require 'ciri/chain/transaction'
require 'ciri/utils'
require 'ciri/db/backend/memory'
require 'ciri/forks'

RSpec.describe Ciri::Chain::Transaction do

  before(:all) do
    prepare_ethereum_fixtures
  end

  parse_account = proc do |address, v|
    address = Ciri::Utils.hex_to_data(address)
    balance = Ciri::Utils.big_endian_decode Ciri::Utils.hex_to_data(v["balance"])
    nonce = Ciri::Utils.big_endian_decode Ciri::Utils.hex_to_data(v["nonce"])
    storage = v["storage"].map do |k, v|
      [Ciri::Utils.hex_to_data(k), Ciri::Utils.hex_to_data(v).rjust(32, "\x00".b)]
    end.to_h
    Ciri::EVM::Account.new(address: address, balance: balance, nonce: nonce, storage: storage)
  end

  run_test_case = proc do |test_case, prefix: nil|
    test_case.each do |name, t|

      %w{Byzantium Constantinople EIP150 EIP158 Frontier Homestead}.each do |fork_name|

        # skip invalid tests now
        next skip if t[fork_name].empty?

        it "#{prefix} #{name} #{fork_name}" do
          expect_result = t[fork_name]
          # expect do
          #   transaction = begin
          #     Ciri::Chain::Transaction.rlp_decode! Ciri::Utils.hex_to_data(t['rlp'])
          #   rescue Ciri::RLP::InvalidValueError, Ciri::Types::Errors::InvalidError
          #     raise Ciri::Chain::Transaction::InvalidError
          #   end
          #
          #   transaction.validate!(intrinsic_gas_of_transaction: Ciri::Forks.detect_fork.intrinsic_gas_of_transaction)
          #
          # end.to raise_error Ciri::Chain::Transaction::InvalidError
          transaction = Ciri::Chain::Transaction.rlp_decode! Ciri::Utils.hex_to_data(t['rlp'])
          expect(Ciri::Utils.data_to_hex transaction.get_hash).to eq expect_result['hash']
          expect(Ciri::Utils.data_to_hex transaction.sender).to eq expect_result['sender']
        end

      end
    end
  end

  skip_topics = %w{}.map {|f| [f, true]}.to_h

  Dir.glob("fixtures/TransactionTests/*").each do |topic|
    # skip topics
    if skip_topics.include? topic
      skip topic
      next
    end

    Dir.glob("#{topic}/*.json").each do |t|
      run_test_case[JSON.load(open t), prefix: topic]
    end
  end

end
