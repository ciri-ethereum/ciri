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
require 'ciri/evm'
require 'ciri/evm/state'
require 'ciri/types/account'
require 'ciri/forks/frontier'
require 'ciri/utils'
require 'ciri/db/backend/memory'
require 'ciri/chain/transaction'
require 'ciri/key'

RSpec.describe Ciri::EVM do

  before(:all) do
    prepare_ethereum_fixtures
  end

  def parse_account(v)
    balance = Ciri::Utils.hex_to_number(v["balance"])
    nonce = Ciri::Utils.hex_to_number(v["nonce"])
    code = Ciri::Utils.to_bytes(v["code"])
    storage = v["storage"].map do |k, v|
      [Ciri::Utils.hex_to_number(k), Ciri::Utils.hex_to_number(v)]
    end.to_h
    [Ciri::Types::Account.new(balance: balance, nonce: nonce), code, storage]
  end

  def build_transaction(transaction_data, args)
    key = Ciri::Key.new(raw_private_key: Ciri::Utils.to_bytes(transaction_data['secretKey']))
    transaction = Ciri::Chain::Transaction.new(
        data: Ciri::Utils.to_bytes(transaction_data['data'][args['data']]),
        gas_limit: Ciri::Utils.hex_to_number(transaction_data['gasLimit'][args['gas']]),
        gas_price: Ciri::Utils.hex_to_number(transaction_data['gasPrice']),
        nonce: Ciri::Utils.hex_to_number(transaction_data['nonce']),
        to: Ciri::Types::Address.new(Ciri::Utils.to_bytes(transaction_data['to'])),
        value: Ciri::Utils.hex_to_number(transaction_data['value'][args['value']])
    )
    transaction.sign_with_key!(key)
    transaction
  end

  def choose_fork_schema(fork_name)
    case fork_name
    when 'Frontier'
      Ciri::Forks::Frontier::Schema.new
    when 'Homestead'
      Ciri::Forks::Homestead::Schema.new(support_dao_fork: false)
    when 'EIP150'
      Ciri::Forks::TangerineWhistle::Schema.new
    when 'EIP158'
      Ciri::Forks::SpuriousDragon::Schema.new
    when 'Byzantium'
      Ciri::Forks::Byzantium::Schema.new
    when 'Constantinople'
      Ciri::Forks::Constantinople::Schema.new
    else
      raise ArgumentError.new("unknown fork #{fork_name}")
    end
  end

  def self.block_info_from_env(env)
    return nil unless env
    Ciri::EVM::BlockInfo.new(
        coinbase: Ciri::Utils.to_bytes(env['currentCoinbase']),
        difficulty: env['currentDifficulty'].to_i(16),
        gas_limit: env['currentGasLimit'].to_i(16),
        number: env['currentNumber'].to_i(16),
        timestamp: env['currentTimestamp'].to_i(16),
    )
  end

  def prepare_state(state, fixture)
    fixture['pre'].each do |address, v|
      address = Ciri::Types::Address.new Ciri::Utils.to_bytes(address)

      account, code, storage = parse_account(v)
      state.set_balance(address, account.balance)
      state.set_nonce(address, account.nonce)
      state.set_account_code(address, code)

      storage.each do |key, value|
        state.store(address, key, value)
      end
    end
  end

  def self.run_test_case(test_case, prefix: nil, tags: {})
    test_case.each do |name, t|
      context "#{prefix} #{name}", **tags do

        block_info = block_info_from_env(t['env'])

        t['post'].each do |fork_name, configs|
          it fork_name do
            fork_schema = choose_fork_schema(fork_name)
            configs.each do |config|
              db = Ciri::DB::Backend::Memory.new
              state = Ciri::EVM::State.new(db)
              prepare_state(state, t)

              indexes = config['indexes']
              transaction = build_transaction(t['transaction'], indexes)
              transaction.sender

              evm = Ciri::EVM.new(state: state, fork_schema: fork_schema)
              result = begin
                evm.execute_transaction(transaction, block_info: block_info, ignore_exception: true)
              rescue StandardError
                Ciri::EVM::ExecutionResult.new(logs: [])
              end

              if config['logs']
                expect(Ciri::Utils.to_hex result.logs_hash).to eq config['logs']
              end

            end
          end
        end

      end

    end
  end

  slow_cases = %w{
    stDelegatecallTestHomestead/Call1024BalanceTooLow.json
    stDelegatecallTestHomestead/Delegatecall1024.json
    stDelegatecallTestHomestead/CallLoseGasOOG.json
    stReturnDataTest/returndatasize_after_oog_after_deeper.json
  }.map {|f| ["fixtures/GeneralStateTests/#{f}", true]}.to_h

  slow_topics = %w{
    stRevertTest
    stCallCreateCallCodeTest
    stChangedEIP150
    stAttackTest
    stQuadraticComplexityTest
  }.map {|f| ["fixtures/GeneralStateTests/#{f}", true]}.to_h

  Dir.glob("fixtures/GeneralStateTests/*").each do |topic|
    tags = {}
    # tag slow test topics
    if slow_topics.include?(topic)
      tags[:slow_tests] = true
    end

    Dir.glob("#{topic}/*.json").each do |t|
      tags = tags.dup
      # tag slow test cases
      if slow_cases.include?(t)
        tags[:slow_tests] = true
      end

      run_test_case(JSON.load(open t), prefix: topic, tags: tags)
    end
  end

end
