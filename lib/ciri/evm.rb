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


require_relative 'evm/op'
require_relative 'evm/vm'
require 'ciri/forks'

module Ciri
  class EVM

    BLOCK_REWARD = 3 * 10.pow(18) # 3 ether

    attr_reader :state

    def initialize(state:)
      @state = state
    end

    # run block
    def finalize_block(block)
      # validate block
      # transition
      # apply_changes
    end

    def validate_block(block)
      # valid ommers
      # valid transactions(block.gas_used == transactions...gas)
      # Reward miner, ommers(reward == block reward + ommers reward)
      # apply changes
      # verify state and block nonce
      # 1. parent header root == trie(state[i]) 当前状态的 root 相等, 返回 state[i] otherwise state[0]
    end

    # transition block
    # block -> new block(mining)
    # return new_block and status change
    def transition(block)
      # execute transactions, we don't need to valid transactions, it should be done before evm(in Chain module).
      block.transactions.each do |transaction|
        transact(transaction, header: block.header)
      end
      # status transfer
      # state[c].balance += mining reward
      # ommers: state[u.c].balance += uncle reward
      #
      # block.nonce
      # block.mix
      # R[i].gas_used = gas_used(state[i - 1], block.transactions[i]) + R[i - 1].gas_used
      # R[i].logs = logs(state[i - 1], block.transactions[i])
      # R[i].z = z(state[i - 1], block.transactions[i])
    end

    # execute transaction
    # @param t Transaction
    # @param header Chain::Header
    def transact(t, header: nil, block_info: nil)
      instruction = Instruction.new(
        address: t.sender,
        origin: t.sender,
        price: t.gas_price,
        sender: t.sender,
        value: t.value,
        header: header
      )

      if t.contract_creation?
        instruction.bytes_code = t.data
      else
        if (account = state[t.to.to_s])
          instruction.bytes_code = account.code
        end
        instruction.data = t.data
      end

      @vm = VM.spawn(
        state: state,
        gas_limit: t.gas_limit,
        instruction: instruction,
        header: header,
        block_info: block_info,
        fork_config: Ciri::Forks.detect_fork(header: header, number: block_info&.number)
      )

      if t.contract_creation?
        # contract creation
        @vm.create_contract
      else
        @vm.run
      end
      nil
    end

    def logs_hash
      return nil unless @vm
      Utils.sha3(RLP.encode_simple(@vm.sub_state.log_series))
    end

  end
end
