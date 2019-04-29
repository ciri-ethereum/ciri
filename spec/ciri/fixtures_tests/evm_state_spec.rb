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
require 'ciri/evm'
require 'ciri/state'
require 'ciri/types/account'
require 'ciri/forks/frontier'
require 'ciri/utils'
require 'ciri/db/backend/memory'
require 'ciri/pow_chain/transaction'
require 'ciri/key'

SLOW_TOPIC = [
  "fixtures/GeneralStateTests/stQuadraticComplexityTest",
  "fixtures/GeneralStateTests/stAttackTest",
]

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
    transaction = Ciri::POWChain::Transaction.new(
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

  def self.run_test_case(test_case, prefix: nil, tags: )

    test_case.each do |name, t|
      context "#{prefix} #{name}", **tags do

        block_info = block_info_from_env(t['env'])

        t['post'].each do |fork_name, configs|
          it fork_name, **tags do
            fork_schema = choose_fork_schema(fork_name)
            configs.each do |config|
              db = Ciri::DB::Backend::Memory.new
              state = Ciri::State.new(db)
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

  Dir.glob("fixtures/GeneralStateTests/*").each do |topic|
    tags = SLOW_TOPIC.include?(topic) ? {slow: true} : {}
    Dir.glob("#{topic}/*.json").each do |t|
      run_test_case(JSON.load(open t), prefix: topic, tags: tags)
    end
  end

end
