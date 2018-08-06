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


require 'ciri/utils/logger'
require 'ciri/core_ext'
require_relative 'errors'
require_relative 'execution_context'
require_relative 'machine_state'
require_relative 'instruction'
require_relative 'sub_state'
require_relative 'block_info'
require_relative 'log_entry'

using Ciri::CoreExt
module Ciri
  class EVM

    # represent empty set, distinguished with nil
    EMPTY_SET = [].freeze

    # Here include batch constants(OP, Cost..) you can find there definition in Ethereum yellow paper.
    # If you can't understand some mystery formula in comments... go to read Ethereum yellow paper.
    #
    # VM: core logic of EVM
    # other logic of EVM (include transaction logic) in EVM module.
    class VM

      extend Forwardable

      # helper methods
      include Utils::Logger

      def_delegators :machine_state, :stack, :pop, :push, :pop_list, :get_stack, :memory_item, :memory_item=,
                     :memory_store, :memory_fetch, :extend_memory
      def_delegators :state, :find_account, :account_dead?, :store, :fetch,
                     :set_account_code, :get_account_code, :account_exist?

      # delegate methods to current execution_context
      def_delegators :execution_context, :instruction, :sub_state, :machine_state, :block_info, :fork_schema,
                     :pc, :output, :exception, :set_output, :set_exception, :set_pc, :status, :depth,
                     :gas_limit, :refund_gas, :reset_refund_gas, :consume_gas, :remain_gas, :jump_to, :jump_pc
      def_delegators :instruction, :get_op, :get_code, :next_valid_instruction_pos, :get_data, :data, :sender, :destinations
      def_delegators :sub_state, :add_refund_account, :add_touched_account, :add_suicide_account

      attr_reader :state, :execution_context, :burn_gas_on_exception, :max_depth, :stack_size

      def initialize(state:, burn_gas_on_exception: true, max_depth: 1024, stack_size: 1024)
        @state = state
        @burn_gas_on_exception = burn_gas_on_exception
        @max_depth = max_depth
        @stack_size = stack_size
      end

      # run vm
      def run(ignore_exception: false)
        execute
        raise exception unless ignore_exception || exception.nil?
      end

      # low_level create_contract interface
      # CREATE_CONTRACT op is based on this method
      def create_contract(context: self.execution_context)
        caller_address = context.instruction.sender
        value = context.instruction.value
        account = find_account(caller_address)

        # return contract address 0 represent execution failed
        return 0 unless account.balance >= value || depth > max_depth
        snapshot = state.snapshot

        # generate contract_address
        material = RLP.encode_simple([caller_address.to_s, account.nonce - 1])
        contract_address = Utils.keccak(material)[-20..-1]

        transact(sender: caller_address, value: value, to: contract_address)

        # initialize contract account
        contract_account = find_account(contract_address)
        context.instruction.address = contract_address
        with_context(context) do
          if contract_account.has_code? || contract_account.nonce > 0
            err = ContractCollisionError.new("address #{contract_address.to_hex} collision")
            debug(err.message)
            set_exception(err)
          else
            execute
          end

          deposit_code_gas = fork_schema.calculate_deposit_code_gas(output)
          gas_is_not_enough = deposit_code_gas > remain_gas
          deposit_code_reach_limit = output.size > fork_schema.contract_code_size_limit

          # check deposit_code_gas
          if gas_is_not_enough || deposit_code_reach_limit
            contract_address = 0
            if fork_schema.exception_on_deposit_code_gas_not_enough
              if deposit_code_reach_limit
                set_exception GasNotEnoughError.new("deposit_code size reach limit, code size: #{output.size}, limit size: #{fork_schema.contract_code_size_limit}")
              else
                set_exception GasNotEnoughError.new("deposit_code_gas not enough, deposit_code_gas: #{deposit_code_gas}, remain_gas: #{remain_gas}")
              end
            else
              set_output ''.b
            end
          elsif exception
            contract_address = 0
          else
            # set contract code
            set_account_code(contract_address, output)
            if fork_schema.contract_init_nonce != 0
              state.set_nonce(contract_address, fork_schema.contract_init_nonce)
            end
            # minus deposit_code_fee
            consume_gas deposit_code_gas
          end

          # check exception and commit/revert state
          if exception
            if burn_gas_on_exception
              debug("exception: #{exception}, burn gas #{remain_gas} to zero... op code: 0x#{get_op(pc).to_s(16)}")
              consume_gas remain_gas
            end
            execution_context.revert
            state.revert(snapshot)
          else
            delete_empty_accounts
            state.commit(snapshot)
          end

          [contract_address, exception]
        end
      end

      # low level call message interface
      # CALL, CALLCODE, DELEGATECALL ops is base on this method
      def call_message(context: self.execution_context, code_address: context.instruction.address)
        address = context.instruction.address
        value = context.instruction.value
        sender = context.instruction.sender
        # return status code 0 represent execution failed
        return [0, ''.b] unless value <= find_account(sender).balance && depth <= max_depth

        snapshot = state.snapshot
        transact(sender: sender, value: value, to: address)
        # enter new execution context
        with_context(context) do
          begin
            if (precompile_contract = fork_schema.find_precompile_contract(code_address))
              precompile_contract.call(self)
            else
              execute
            end
          rescue GasNotEnoughError => e
            set_exception(e)
          end

          if exception
            if burn_gas_on_exception
              debug("exception: #{exception}, burn gas #{remain_gas} to zero... op code: 0x#{get_op(pc).to_s(16)}")
              consume_gas remain_gas
            end
            execution_context.revert

            state.revert(snapshot)
          else
            delete_empty_accounts
            state.commit(snapshot)
          end

          [status, output || ''.b, exception]
        end
      end

      def add_log_entry(topics, log_data)
        sub_state.log_series << LogEntry.new(address: instruction.address, topics: topics, data: log_data)
      end

      # transact value from sender to target address
      def transact(sender:, value:, to:)
        sender_account = find_account(sender)
        raise VMError.new("balance not enough") if sender_account.balance < value
        add_touched_account(sender)
        add_touched_account(to)
        state.add_balance(sender, -value)
        state.add_balance(to, value)
      end

      # Execute instruction with states
      # Ξ(σ,g,I,T) ≡ (σ′,μ′ ,A,o)
      def execute
        loop do
          if exception || set_exception(check_exception(@state, machine_state, instruction))
            debug("check exception: #{exception}")
            return
          elsif get_op(pc) == OP::REVERT
            o = halt
            return
          elsif (o = halt) != EMPTY_SET
            return
          else
            operate
            next
          end
        end
      end

      def with_context(new_context)
        origin_context = execution_context
        @execution_context = new_context
        return_value = yield
        @execution_context = origin_context
        return_value
      end

      def extend_memory(pos, size)
        machine_state.extend_memory(execution_context, pos, size)
      end

      def delete_empty_accounts
        return unless fork_schema.clean_empty_accounts?
        sub_state.touched_accounts.select do |address|
          account_dead?(address)
        end.each do |address|
          state.delete_account(address)
        end
      end

      private

      # O(σ, μ, A, I) ≡ (σ′, μ′, A′, I)
      def operate
        w = get_op(pc)
        operation = fork_schema.get_operation(w)

        raise "can't find operation #{w}, pc #{pc}" unless operation

        op_cost, op_refund = fork_schema.gas_of_operation(self)

        debug("depth: #{depth} pc: #{pc} #{operation.name} gas: #{op_cost} stack: #{stack.size} logs: #{sub_state.log_series.size}")

        consume_gas op_cost
        refund_gas op_refund if op_refund && op_refund > 0

        # call operation
        begin
          operation.call(self)
        rescue VMError => e
          set_exception(e)
        end

        # revert sub_state and return if exception occur
        if exception
          execution_context.revert
          return
        end

        set_pc case
               when w == OP::JUMP
                 jump_pc
               when w == OP::JUMPI && jump_pc
                 jump_pc
               else
                 next_valid_instruction_pos(pc, w)
               end
      end

      # determinate halt or not halt
      def halt
        w = get_op(pc)
        if w == OP::RETURN || w == OP::REVERT
          operate
          output
        elsif w == OP::STOP || w == OP::SELFDESTRUCT
          operate
          # return empty sequence: nil
          # debug("#{pc} #{OP.get(w).name} gas: 0 stack: #{stack.size}")
          nil
        else
          EMPTY_SET
        end
      end

      # check status
      def check_exception(state, ms, instruction)
        w = instruction.get_op(pc)
        case
        when w == OP::INVALID || fork_schema.get_operation(w).nil?
          InvalidOpCodeError.new "can't find op code 0x#{w.to_s(16)} pc: #{pc}"
        when ms.stack.size < (consume = OP.input_count(w))
          StackError.new "stack not enough: stack:#{ms.stack.size} next consume: #{consume}"
        when remain_gas < (gas_cost = fork_schema.gas_of_operation(self).yield_self {|gas_cost, _| gas_cost})
          GasNotEnoughError.new "gas not enough: gas remain:#{remain_gas} gas cost: #{gas_cost}"
        when w == OP::JUMP && !destinations.include?(ms.get_stack(0, Integer))
          InvalidJumpError.new "invalid jump dest #{ms.get_stack(0, Integer)}"
        when w == OP::JUMPI && ms.get_stack(1, Integer) != 0 && !destinations.include?(ms.get_stack(0, Integer))
          InvalidJumpError.new "invalid condition jump dest #{ms.get_stack(0, Integer)}"
        when w == OP::RETURNDATACOPY && ms.get_stack(1, Integer) + ms.get_stack(2, Integer) > ms.output.size
          ReturnError.new "return data copy error"
        when stack.size - OP.input_count(w) + OP.output_count(w) > stack_size
          StackError.new "stack size reach #{stack_size} limit"
        when depth > max_depth
          StackError.new "call depth reach #{max_depth} limit"
        else
          nil
        end
      end

    end
  end
end
