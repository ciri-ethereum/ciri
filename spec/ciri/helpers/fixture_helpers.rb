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


require 'yaml'
require 'json'

require 'ciri/core_ext'
require 'ciri/pow_chain/chain'

using Ciri::CoreExt

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
      data[k] = Ciri::Utils.dehex(data[k]) if data.has_key?(k)
    end
    %i{difficulty gas_used gas_limit number timestamp}.each do |k|
      data[k] = Ciri::Utils.dehex_number(data[k]) if data.has_key?(k) && !data[k].is_a?(Integer)
    end
    data = data.select {|k, v| Ciri::POWChain::Header.schema.keys.include? k}.to_h
    Ciri::POWChain::Header.new(**data)
  end

  def fixture_to_block(b, data = nil)
    data ||= fixture_normalize(b, BLOCK_HEADER_MAPPING)
    header = fixture_to_block_header(b, data)
    transactions = data[:transactions]
    uncles = data[:uncles].map {|u| fixture_to_block(u).header}

    Ciri::POWChain::Block.new(header: header, transactions: transactions, ommers: uncles)
  end

  TRANSACTION_MAPPING = {}

  def fixture_to_transaction(b, data = nil)
    data ||= fixture_normalize(b, TRANSACTION_MAPPING)
    %i{data to}.each do |k|
      data[k] = Ciri::Utils.dehex(data[k]) if data.has_key?(k)
    end

    data[:to] = Ciri::Types::Address.new(data[:to])

    %i{gas_used gas_limit gas_price nonce r s v value}.each do |k|
      data[k] = Ciri::Utils.dehex_number(data[k]) if data.has_key?(k)
    end

    Ciri::POWChain::Transaction.new(**data)
  end

  def fixture_normalize(b, mapping = {})
    b.map do |k, v|
      k = Ciri::Utils.to_underscore(k).to_sym
      k = mapping[k] if mapping.has_key?(k)
      [k, v]
    end.to_h
  end

  def load_blocks(file)
    require 'ciri/pow_chain/chain'

    fixture(file).map do |b|
      fixture_to_block(b)
    end
  end

  def parse_account(account_hash)
    storage = account_hash["storage"].map do |k, v|
      [k.dehex.big_endian_decode, v.dehex.big_endian_decode]
      #[k.dehex, v.dehex.pad_zero(32)]
    end.to_h
    account = Ciri::Types::Account.new(
        balance: account_hash["balance"].dehex.big_endian_decode,
        nonce: account_hash["nonce"].dehex.big_endian_decode)
    code = account_hash['code'].dehex
    [account, code, storage]
  end

  def parse_header(data)
    columns = {}
    columns[:logs_bloom] = data['bloom'].dehex
    columns[:beneficiary] = data['coinbase'].dehex
    columns[:difficulty] = data['difficulty'].dehex.big_endian_decode
    columns[:extra_data] = data['extraData'].dehex
    columns[:gas_limit] = data['gasLimit'].dehex.big_endian_decode
    columns[:gas_used] = data['gasUsed'].dehex.big_endian_decode
    columns[:mix_hash] = data['mixHash'].dehex
    columns[:nonce] = data['nonce'].dehex
    columns[:number] = data['number'].dehex.big_endian_decode
    columns[:parent_hash] = data['parentHash'].dehex
    columns[:receipts_root] = data['receiptTrie'].dehex
    columns[:state_root] = data['stateRoot'].dehex
    columns[:transactions_root] = data['transactionsTrie'].dehex
    columns[:timestamp] = data['timestamp'].dehex.big_endian_decode
    columns[:ommers_hash] = data['uncleHash'].dehex

    header = Ciri::POWChain::Header.new(**columns)
    unless Ciri::Utils.hex(header.get_hash) == data['hash']
      error columns
    end
    header
  end

  def extract_fork_config(fixture)
    network = fixture['network']
    schema_rules = case network
                   when "Frontier"
                     [
                         [0, Ciri::Forks::Frontier::Schema.new],
                     ]
                   when "Homestead"
                     [
                         [0, Ciri::Forks::Homestead::Schema.new(support_dao_fork: false)],
                     ]
                   when "EIP150"
                     [
                         [0, Ciri::Forks::TangerineWhistle::Schema.new],
                     ]
                   when "EIP158"
                     [
                         [0, Ciri::Forks::SpuriousDragon::Schema.new],
                     ]
                   when "Byzantium"
                     [
                         [0, Ciri::Forks::Byzantium::Schema.new],
                     ]
                   when "Constantinople"
                     [
                         [0, Ciri::Forks::Constantinople::Schema.new],
                     ]
                   when "FrontierToHomesteadAt5"
                     [
                         [0, Ciri::Forks::Frontier::Schema.new],
                         [5, Ciri::Forks::Homestead::Schema.new(support_dao_fork: false)],
                     ]
                   when "HomesteadToEIP150At5"
                     [
                         [0, Ciri::Forks::Homestead::Schema.new(support_dao_fork: false)],
                         [5, Ciri::Forks::TangerineWhistle::Schema.new],
                     ]
                   when "HomesteadToDaoAt5"
                     [
                         [0, Ciri::Forks::Homestead::Schema.new(support_dao_fork: true, dao_fork_block_number: 5)],
                     ]
                   when "EIP158ToByzantiumAt5"
                     [
                         [0, Ciri::Forks::SpuriousDragon::Schema.new],
                         [5, Ciri::Forks::Byzantium::Schema.new],
                     ]
                   else
                     raise ArgumentError.new("unknown network: #{network}")
                   end

    Ciri::Forks::Config.new(schema_rules)
  end

  def prepare_state(state, fixture)
    fixture['pre'].each do |address, v|
      address = Ciri::Types::Address.new address.dehex

      account, code, storage = parse_account v
      state.set_balance(address, account.balance)
      state.set_nonce(address, account.nonce)
      state.set_account_code(address, code)

      storage.each do |key, value|
        # key, value = k.big_endian_decode, v.big_endian_decode
        state.store(address, key, value)
      end
    end
  end

end

