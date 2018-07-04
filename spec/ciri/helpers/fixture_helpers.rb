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
