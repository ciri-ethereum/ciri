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
    address = Ciri::Utils.to_bytes(address)
    balance = Ciri::Utils.big_endian_decode Ciri::Utils.to_bytes(v["balance"])
    nonce = Ciri::Utils.big_endian_decode Ciri::Utils.to_bytes(v["nonce"])
    storage = v["storage"].map do |k, v|
      [Ciri::Utils.to_bytes(k), Ciri::Utils.to_bytes(v).rjust(32, "\x00".b)]
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
          #     Ciri::Chain::Transaction.rlp_decode Ciri::Utils.hex_to_data(t['rlp'])
          #   rescue Ciri::RLP::InvalidValueError, Ciri::Types::Errors::InvalidError
          #     raise Ciri::Chain::Transaction::InvalidError
          #   end
          #
          #   transaction.validate!(intrinsic_gas_of_transaction: Ciri::Forks.detect_fork.intrinsic_gas_of_transaction)
          #
          # end.to raise_error Ciri::Chain::Transaction::InvalidError
          transaction = Ciri::Chain::Transaction.rlp_decode Ciri::Utils.to_bytes(t['rlp'])
          expect(Ciri::Utils.to_hex transaction.get_hash).to eq "0x#{expect_result['hash']}"
          expect(Ciri::Utils.to_hex transaction.sender).to eq "0x#{expect_result['sender']}"
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
