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


require 'forwardable'
require 'ciri/forks'
require_relative 'evm/op'
require_relative 'evm/vm'
require_relative 'types/account'

module Ciri
  class EVM
    extend Forwardable

    class InvalidTransition < StandardError
    end

    ExecutionResult = Struct.new(:status, :state_root, :logs, :gas_used, :gas_price, :exception, keyword_init: true)

    def_delegators :@state, :find_account, :account_dead?, :get_account_code, :state_root

    attr_reader :state

    def initialize(state:)
      @state = state
    end

    # transition block
    def transition(block, check_gas_limit: true, check_gas_used: true)
      results = []

      total_gas_used = 0
      # execute transactions, we don't need to valid transactions, it should be done before evm(in Chain module).
      block.transactions.each do |transaction|
        result = execute_transaction(transaction, header: block.header, ignore_exception: true)

        total_gas_used += result.gas_used
        if check_gas_limit && total_gas_used > block.header.gas_limit
          raise InvalidTransition.new('reach block gas_limit')
        end
        if check_gas_used && total_gas_used > block.header.gas_used
          raise InvalidTransition.new('incorrect gas_used')
        end

        # calculate fee
        fee = result.gas_used * result.gas_price
        sender_account = find_account(transaction.sender)
        sender_account.balance -= fee
        state.set_balance(transaction.sender, sender_account.balance)

        miner_account = find_account(block.header.beneficiary)
        miner_account.balance += fee
        state.set_balance(block.header.beneficiary, miner_account.balance)

        results << result
      end

      if check_gas_used && total_gas_used != block.header.gas_used
        raise InvalidTransition.new("incorrect gas_used, actual used: #{total_gas_used} header: #{block.header.gas_used}")
      end

      fork_config = Ciri::Forks.detect_fork(header: block.header, number: block.header.number)
      rewards = fork_config.mining_rewards[block]

      # apply rewards
      rewards.each do |address, value|
        if value > 0
          account = find_account(address)
          account.balance += value
          state.set_balance(address, account.balance)
        end
      end

      results
    end

    # execute transaction
    # @param t Transaction
    # @param header Chain::Header
    def execute_transaction(t, header: nil, block_info: nil, ignore_exception: false)
      instruction = Instruction.new(
        origin: t.sender,
        price: t.gas_price,
        sender: t.sender,
        value: t.value,
        header: header,
        execute_depth: 0,
      )

      if t.contract_creation?
        instruction.bytes_code = t.data
        instruction.address = t.sender
      else
        instruction.bytes_code = get_account_code(t.to)
        instruction.address = t.to
        instruction.data = t.data
      end

      fork_config = Ciri::Forks.detect_fork(header: header, number: block_info&.number)

      @vm = VM.spawn(
        state: state,
        gas_limit: t.gas_limit,
        instruction: instruction,
        header: header,
        block_info: block_info,
        fork_config: fork_config
      )

      if t.contract_creation?
        # contract creation
        @vm.create_contract(value: instruction.value, init: instruction.bytes_code)
      else
        # transact ether
        begin
          @vm.transact(sender: t.sender, value: t.value, to: t.to)
        rescue VM::VMError
          raise unless ignore_exception
          return nil
        end
        @vm.run(ignore_exception: ignore_exception)
      end
      gas_used = t.gas_limit - @vm.gas_remain + fork_config.intrinsic_gas_of_transaction[t]
      state_root = state.respond_to?(:root_hash) ? state.root_hash : nil
      ExecutionResult.new(status: @vm.status, state_root: state_root, logs: logs_hash, gas_used: gas_used,
                          gas_price: t.gas_price, exception: @vm.exception)
    end

    def logs_hash
      return nil unless @vm
      Utils.sha3(RLP.encode_simple(@vm.sub_state.log_series))
    end

  end
end
