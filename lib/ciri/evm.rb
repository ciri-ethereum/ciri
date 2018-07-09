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
require_relative 'evm/errors'
require_relative 'types/account'
require_relative 'types/receipt'

module Ciri
  class EVM
    extend Forwardable

    ExecutionResult = Struct.new(:status, :state_root, :logs, :gas_used, :gas_price, :exception, keyword_init: true)

    def_delegators :@state, :find_account, :account_dead?, :get_account_code, :state_root

    attr_reader :state

    def initialize(state:)
      @state = state
    end

    # transition block
    def transition(block, check_gas_limit: true, check_gas_used: true)
      receipts = []

      total_gas_used = 0
      # execute transactions, we don't need to valid transactions, it should be done before evm(in Chain module).
      block.transactions.each do |transaction|
        result = execute_transaction(transaction, header: block.header, ignore_exception: true)

        total_gas_used += result.gas_used
        if check_gas_limit && total_gas_used > block.header.gas_limit
          raise InvalidTransition.new('reach block gas_limit')
        end
        if check_gas_used && total_gas_used > block.header.gas_used
          raise InvalidTransition.new("incorrect gas_used, total_gas_used: #{total_gas_used}, block gas_used: #{block.header.gas_used}")
        end

        # calculate fee
        fee = result.gas_used * result.gas_price

        miner_account = find_account(block.header.beneficiary)
        miner_account.balance += fee
        state.set_balance(block.header.beneficiary, miner_account.balance)

        # update actually state_root(after calculate fee)
        result.state_root = state.state_root

        receipts << Types::Receipt.new(state_root: result.state_root, gas_used: total_gas_used, logs: result.logs)
      end

      if check_gas_used && total_gas_used != block.header.gas_used
        raise InvalidTransition.new("incorrect gas_used, actual used: #{total_gas_used} header: #{block.header.gas_used}")
      end

      fork_config = Ciri::Forks.detect_fork(header: block.header, number: block.header.number)
      rewards = fork_config.mining_rewards_of_block(block)

      # apply rewards
      rewards.each do |address, value|
        if value > 0
          account = find_account(address)
          account.balance += value
          state.set_balance(address, account.balance)
        end
      end

      receipts
    end

    # execute transaction
    # @param t Transaction
    # @param header Chain::Header
    def execute_transaction(t, header: nil, block_info: nil, ignore_exception: false)
      unless state.find_account(t.sender).balance >= t.gas_price * t.gas_limit + t.value
        raise InvalidTransaction.new('account balance not enough')
      end

      # remove gas fee from account balance
      state.add_balance(t.sender, -1 * t.gas_limit * t.gas_price)
      fork_config = Ciri::Forks.detect_fork(header: header, number: block_info&.number)

      gas_limit = t.gas_limit - fork_config.intrinsic_gas_of_transaction(t)

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

      @vm = VM.spawn(
        state: state,
        gas_limit: gas_limit,
        instruction: instruction,
        header: header,
        block_info: block_info,
        fork_config: fork_config
      )

      # transact ether
      exception = nil
      # begin
      if t.contract_creation?
        # contract creation
        _, exception = @vm.create_contract(value: instruction.value, init: instruction.bytes_code)
      else
        _, _, exception = @vm.call_message(sender: t.sender, value: t.value, receipt: t.to, data: t.data)
      end
      # rescue ArgumentError => e
      #   raise unless ignore_exception
      #   exception = e
      # end
      raise exception if !ignore_exception && exception

      # refund gas
      refund_gas = fork_config.calculate_refund_gas(@vm)
      gas_used = t.gas_limit - @vm.remain_gas
      refund_gas = [refund_gas, gas_used / 2].min
      state.add_balance(t.sender, (refund_gas + @vm.remain_gas) * t.gas_price)

      # destroy accounts
      @vm.sub_state.suicide_accounts.each do |address|
        state.set_balance(address, 0)
        state.delete_account(address)
      end

      ExecutionResult.new(status: @vm.status, state_root: state_root, logs: @vm.sub_state.log_series, gas_used: gas_used - refund_gas,
                          gas_price: t.gas_price, exception: @vm.exception)
    end

    def logs_hash
      # return nil unless @vm
      Utils.keccak(RLP.encode_simple(vm.sub_state.log_series))
    end

    private

    def vm
      @vm ||= VM.spawn(
        state: state,
        gas_limit: 0,
        instruction: nil,
        block_info: BlockInfo.new,
        fork_config: nil
      )
    end

  end
end
