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


require 'yaml'
require 'json'

require 'ciri/chain'

module FixtureHelpers
  FIXTURE_DIR = "spec/fixtures"

  def fixture(file)
    path = FIXTURE_DIR + '/' + file
    extname = File.extname(path)

    # guess file
    if extname.empty? && !File.exist?(path)
      if File.exist? path + '.json'
        extname = '.json'
      elsif File.exist? path + '.yaml'
        extname = '.yaml'
      elsif File.exist? path + '.yml'
        extname = '.yml'
      end
      path += extname
    end

    f = open(path)
    if extname == '.yaml' || extname == '.yml'
      YAML.load(f.read)
    elsif extname == '.json'
      JSON.parse(f.read)
    else
      f.read
    end
  end

  BLOCK_HEADER_MAPPING = {
    bloom: :logs_bloom,
    coinbase: :beneficiary,
    miner: :beneficiary,
    sha3_uncles: :ommers_hash,
    uncle_hash: :ommers_hash,
    receipt_trie: :receipts_root,
    transactions_trie: :transactions_root,
  }

  def fixture_to_block_header(b, data = nil)
    data ||= fixture_normalize(b, BLOCK_HEADER_MAPPING)
    # convert hex to binary
    %i{extra_data hash logs_bloom beneficiary mix_hash nonce parent_hash receipts_root ommers_hash state_root transactions_root}.each do |k|
      data[k] = Ciri::Utils.to_bytes(data[k]) if data.has_key?(k)
    end
    %i{difficulty gas_used gas_limit number timestamp}.each do |k|
      data[k] = Ciri::Utils.hex_to_number(data[k]) if data.has_key?(k) && !data[k].is_a?(Integer)
    end
    data = data.select {|k, v| Ciri::Chain::Header.schema.keys.include? k}.to_h
    Ciri::Chain::Header.new(**data)
  end

  def fixture_to_block(b, data = nil)
    data ||= fixture_normalize(b, BLOCK_HEADER_MAPPING)
    header = fixture_to_block_header(b, data)
    transactions = data[:transactions]
    uncles = data[:uncles].map {|u| fixture_to_block(u).header}

    Ciri::Chain::Block.new(header: header, transactions: transactions, ommers: uncles)
  end

  TRANSACTION_MAPPING = {}

  def fixture_to_transaction(b, data = nil)
    data ||= fixture_normalize(b, TRANSACTION_MAPPING)
    %i{data to}.each do |k|
      data[k] = Ciri::Utils.to_bytes(data[k]) if data.has_key?(k)
    end

    data[:to] = Ciri::Types::Address.new(data[:to])

    %i{gas_used gas_limit gas_price nonce r s v value}.each do |k|
      data[k] = Ciri::Utils.hex_to_number(data[k]) if data.has_key?(k)
    end

    Ciri::Chain::Transaction.new(**data)
  end

  def fixture_normalize(b, mapping = {})
    b.map do |k, v|
      k = Ciri::Utils.to_underscore(k).to_sym
      k = mapping[k] if mapping.has_key?(k)
      [k, v]
    end.to_h
  end

  def load_blocks(file)
    require 'ciri/chain'

    fixture(file).map do |b|
      fixture_to_block(b)
    end
  end

end
