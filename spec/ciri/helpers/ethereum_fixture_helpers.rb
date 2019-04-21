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

using Ciri::CoreExt

module EthereumFixtureHelpers

  def prepare_ethereum_fixtures
    system('git submodule init')
    system('git submodule update fixtures')
  end

  def parse_account(account_hash)
    storage = account_hash["storage"].map do |k, v|
      [k.decode_hex, v.decode_hex.pad_zero(32)]
    end.to_h
    account = Ciri::Types::Account.new(
        balance: account_hash["balance"].decode_hex.decode_big_endian,
        nonce: account_hash["nonce"].decode_hex.decode_big_endian)
    code = account_hash['code'].decode_hex
    [account, code, storage]
  end

  def parse_header(data)
    columns = {}
    columns[:logs_bloom] = data['bloom'].decode_hex
    columns[:beneficiary] = data['coinbase'].decode_hex
    columns[:difficulty] = data['difficulty'].decode_hex.decode_big_endian
    columns[:extra_data] = data['extraData'].decode_hex
    columns[:gas_limit] = data['gasLimit'].decode_hex.decode_big_endian
    columns[:gas_used] = data['gasUsed'].decode_hex.decode_big_endian
    columns[:mix_hash] = data['mixHash'].decode_hex
    columns[:nonce] = data['nonce'].decode_hex
    columns[:number] = data['number'].decode_hex.decode_big_endian
    columns[:parent_hash] = data['parentHash'].decode_hex
    columns[:receipts_root] = data['receiptTrie'].decode_hex
    columns[:state_root] = data['stateRoot'].decode_hex
    columns[:transactions_root] = data['transactionsTrie'].decode_hex
    columns[:timestamp] = data['timestamp'].decode_hex.decode_big_endian
    columns[:ommers_hash] = data['uncleHash'].decode_hex

    header = Ciri::POWChain::Header.new(**columns)
    unless Ciri::Utils.to_hex(header.get_hash) == data['hash']
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
      address = Ciri::Types::Address.new address.decode_hex

      account, code, storage = parse_account v
      state.set_balance(address, account.balance)
      state.set_nonce(address, account.nonce)
      state.set_account_code(address, code)

      storage.each do |k, v|
        key, value = k.decode_big_endian, v.decode_big_endian
        state.store(address, key, value)
      end
    end
  end

end
