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


require 'ciri/utils/logger'
require_relative 'errors'
require_relative 'machine_state'
require_relative 'instruction'
require_relative 'sub_state'
require_relative 'block_info'
require_relative 'log_entry'

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

      def_delegators :@machine_state, :stack, :pop, :push, :pop_list, :get_stack, :memory_item, :memory_item=,
                     :memory_store, :memory_fetch, :extend_memory
      def_delegators :@state, :find_account, :account_dead?, :store, :fetch, :set_account_code, :get_account_code

      # delegate methods to current execution_context
      def_delegators :execution_context, :instruction, :sub_state, :consume_gas, :remain_gas, :block_info, :fork_schema,
                     :pc, :output, :exception, :set_output, :set_exception, :set_pc, :status, :gas_limit, :depth
      def_delegators :instruction, :get_op, :get_code, :next_valid_instruction_pos, :get_data, :data, :sender
      def_delegators :sub_state, :add_refund_account, :add_touched_account, :add_suicide_account

      attr_reader :state, :machine_state, :execution_context

      def initialize(state:, machine_state: MachineState.new, burn_gas_on_exception: true)
        @state = state
        @machine_state = machine_state
        @burn_gas_on_exception = burn_gas_on_exception
      end

      # run vm
      def run(ignore_exception: false)
        execute
        raise exception unless ignore_exception || exception.nil?
      end

      # low_level create_contract interface
      # CREATE_CONTRACT op is based on this method
      def create_contract(value:, init:, gas_limit: self.gas_limit)
        caller_address = instruction.address
        account = find_account(caller_address)

        # return contract address 0 represent execution failed
        return 0 unless account.balance >= value || depth > 1024

        state.increment_nonce(caller_address)
        snapshot = state.snapshot

        # generate contract_address
        material = RLP.encode_simple([caller_address.to_s, account.nonce])
        contract_address = Utils.keccak(material)[-20..-1]

        # initialize contract account
        contract_account = find_account(contract_address)
        # contract_account.nonce = 1

        # execute initialize code
        new_context = execution_context.child_context(gas_limit: gas_limit)
        new_context.instruction = instruction.dup
        new_context.instruction.bytes_code = init
        new_context.instruction.address = contract_address

        with_context(new_context) do
          execute

          deposit_code_gas = fork_schema.calculate_deposit_code_gas(output)

          if deposit_code_gas > remain_gas
            # deposit_code_gas not enough
            contract_address = 0
          elsif exception
            state.touch_account(contract_address)
            contract_address = 0
            state.revert(snapshot)
          else
            # set contract code
            set_account_code(contract_address, output)
            # minus deposit_code_fee
            consume_gas deposit_code_gas
            # transact value
            account.balance -= value
            contract_account.balance += value

            state.set_balance(contract_address, contract_account.balance)
            state.set_balance(caller_address, account.balance)
            state.commit(snapshot)
          end
          [contract_address, exception]
        end
      end

      # low level call message interface
      # CALL, CALLCODE, DELEGATECALL ops is base on this method
      def call_message(sender:, value:, target:, data:, code_address: target, gas_limit: self.gas_limit)
        # return status code 0 represent execution failed
        return [0, ''.b] unless value <= find_account(sender).balance && depth <= 1024

        state.increment_nonce(sender)

        snapshot = state.snapshot

        transact(sender: sender, value: value, to: target)

        # execute initialize code
        new_context = execution_context.child_context(gas_limit: gas_limit)
        new_context.instruction = instruction.dup
        new_context.instruction.address = target
        new_context.instruction.sender = sender
        new_context.instruction.value = value
        new_context.instruction.data = data
        new_context.instruction.bytes_code = get_account_code(code_address)

        with_context(new_context) do
          execute

          if exception
            state.revert(snapshot)
          else
            state.commit(snapshot)
          end

          [status, output || ''.b, exception]
        end
      end

      # jump to pc
      # only valid if current op code is allowed to modify pc
      def jump_to(pc)
        @jump_to = pc
      end

      def add_log_entry(topics, log_data)
        sub_state.log_series << LogEntry.new(address: instruction.address, topics: topics, data: log_data)
      end

      # transact value from sender to target address
      def transact(sender:, value:, to:)
        sender_account = find_account(sender)
        to_account = find_account(to)

        raise VMError.new("balance not enough") if sender_account.balance < value

        sender_account.balance -= value
        to_account.balance += value

        state.set_nonce(sender, sender_account.nonce)
        state.set_balance(sender, sender_account.balance)
        state.set_balance(to, to_account.balance)
      end

      # Execute instruction with states
      # Ξ(σ,g,I,T) ≡ (σ′,μ′ ,A,o)
      def execute
        loop do
          if exception || set_exception(check_exception(@state, machine_state, instruction))
            if @burn_gas_on_exception
              debug("exception: #{exception}, burn gas #{remain_gas} to zero")
              consume_gas remain_gas
            end
            return [EMPTY_SET, machine_state, SubState::EMPTY, instruction, EMPTY_SET]
          elsif get_op(pc) == OP::REVERT
            o = halt
            return [EMPTY_SET, machine_state, SubState::EMPTY, instruction, o]
          elsif (o = halt) != EMPTY_SET
            return [@state, machine_state, sub_state, instruction, o]
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

      private

      # O(σ, μ, A, I) ≡ (σ′, μ′, A′, I)
      def operate
        ms = machine_state
        w = get_op(pc)
        operation = OP.get(w)

        raise "can't find operation #{w}, pc #{pc}" unless operation

        op_cost = fork_schema.gas_of_operation(self)
        consume_gas op_cost

        # call operation
        begin
          operation.call(self)
        rescue VMError => e
          set_exception(e)
        end

        # revert sub_state and return if exception occur
        if exception
          @sub_state = SubState::EMPTY
          return
        end

        debug("depth: #{depth} pc: #{pc} #{operation.name} gas: #{op_cost} stack: #{stack.size} logs: #{sub_state.log_series.size}")
        set_pc case
               when w == OP::JUMP
                 @jump_to
               when w == OP::JUMPI
                 @jump_to
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
        when w == OP::INVALID
          InvalidOpCodeError.new "can't find op code 0x#{w.to_s(16)}"
        when OP.input_count(w).nil?
          InvalidOpCodeError.new "can't find op code 0x#{w.to_s(16)}"
        when ms.stack.size < (consume = OP.input_count(w))
          StackError.new "stack not enough: stack:#{ms.stack.size} next consume: #{consume}"
        when remain_gas < (gas_cost = fork_schema.gas_of_operation(self))
          GasNotEnoughError.new "gas not enough: gas remain:#{remain_gas} gas cost: #{gas_cost}"
        when w == OP::JUMP && instruction.destinations.include?(ms.get_stack(0, Integer))
          InvalidJumpError.new "invalid jump dest #{ms.get_stack(0, Integer)}"
        when w == OP::JUMPI && ms.get_stack(1, Integer) != 0 && instruction.destinations.include?(ms.get_stack(0, Integer))
          InvalidJumpError.new "invalid condition jump dest #{ms.get_stack(0, Integer)}"
        when w == OP::RETURNDATACOPY && ms.get_stack(1, Integer) + ms.get_stack(2, Integer) > ms.output.size
          ReturnError.new "return data copy error"
        when stack.size - OP.input_count(w) + OP.output_count(w) > 1024
          StackError.new "stack size reach 1024 limit"
          # A condition in yellow paper but I can't understand..: (¬Iw ∧W(w,μ))
        when depth > 1024
          StackError.new "call depth reach 1024 limit"
        else
          nil
        end
      end

    end
  end
end
