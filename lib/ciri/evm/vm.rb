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

      class << self
        # this method provide a simpler interface to create VM and execute code
        # VM.spawn(...) == VM.new(...)
        # @return VM
        def spawn(state:, gas_limit:, header: nil, block_info: nil, instruction: EVM::Instruction.new, fork_schema:)
          ms = MachineState.new(remain_gas: gas_limit, pc: 0, stack: [], memory: "\x00".b * 256, memory_item: 0,
                                fork_schema: fork_schema)

          block_info = block_info || header && BlockInfo.new(
            coinbase: header.beneficiary,
            difficulty: header.difficulty,
            gas_limit: header.gas_limit,
            number: header.number,
            timestamp: header.timestamp,
            parent_hash: header.parent_hash,
            block_hash: header.get_hash,
          )

          vm = VM.new(
            state: state,
            machine_state: ms,
            block_info: block_info,
            instruction: instruction,
            fork_schema: fork_schema
          )
          yield vm if block_given?
          vm
        end
      end

      extend Forwardable

      # helper methods
      include Utils::Logger

      def_delegators :@machine_state, :stack, :pc, :pop, :push, :pop_list, :get_stack, :memory_item, :memory_item=,
                     :memory_store, :memory_fetch, :extend_memory, :remain_gas, :consume_gas
      def_delegators :@instruction, :get_op, :get_code, :next_valid_instruction_pos, :get_data, :data, :sender
      def_delegators :@sub_state, :add_refund_account, :add_touched_account, :add_suicide_account
      def_delegators :@state, :find_account, :account_dead?, :store, :fetch, :set_account_code, :get_account_code

      attr_reader :state, :machine_state, :instruction, :sub_state, :block_info, :fork_schema
      attr_accessor :output, :exception

      def initialize(state:, machine_state:, sub_state: nil, instruction:, block_info:,
                     fork_schema:, burn_gas_on_exception: true)
        @state = state
        @machine_state = machine_state
        @instruction = instruction
        @sub_state = sub_state || SubState.new
        @output = nil
        @block_info = block_info
        @fork_schema = fork_schema
        @burn_gas_on_exception = burn_gas_on_exception
      end

      # run vm
      def run(ignore_exception: false)
        execute
        raise exception unless ignore_exception || exception.nil?
      end

      # low_level create_contract interface
      # CREATE_CONTRACT op is based on this method
      def create_contract(value:, init:)
        caller_address = instruction.address
        account = find_account(caller_address)

        # return contract address 0 represent execution failed
        return 0 unless account.balance >= value || instruction.execute_depth > 1024

        state.increment_nonce(caller_address)
        snapshot = state.snapshot

        # generate contract_address
        material = RLP.encode_simple([caller_address.to_s, account.nonce])
        contract_address = Utils.keccak(material)[-20..-1]

        # initialize contract account
        contract_account = find_account(contract_address)
        # contract_account.nonce = 1

        # execute initialize code
        create_contract_instruction = instruction.dup
        create_contract_instruction.bytes_code = init
        create_contract_instruction.execute_depth += 1
        create_contract_instruction.address = contract_address

        # TODO refactoring: Maybe should use call_message to execute data
        call_instruction(create_contract_instruction) do
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
            machine_state.consume_gas deposit_code_gas
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
      def call_message(sender:, value:, target:, data:, code_address: target)
        # return status code 0 represent execution failed
        return [0, ''.b] unless value <= find_account(sender).balance && instruction.execute_depth <= 1024

        state.increment_nonce(sender)

        snapshot = state.snapshot

        transact(sender: sender, value: value, to: target)

        message_call_instruction = instruction.dup
        message_call_instruction.address = target
        message_call_instruction.sender = sender
        message_call_instruction.value = value

        message_call_instruction.execute_depth += 1

        message_call_instruction.data = data
        message_call_instruction.bytes_code = get_account_code(code_address)

        call_instruction(message_call_instruction) do
          execute

          if exception
            state.revert(snapshot)
          else
            state.commit(snapshot)
          end

          [status, output || ''.b, exception]
        end
      end

      def status
        exception.nil? ? 0 : 1
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

      # call instruction
      def call_instruction(new_instruction)
        origin_instruction = instruction
        origin_pc = pc
        @instruction = new_instruction
        @machine_state.pc = 0

        return_value = yield

        @instruction = origin_instruction
        @machine_state.pc = origin_pc
        # clear up state
        @exception = nil
        @output = ''.b
        return_value
      end

      # Execute instruction with states
      # Ξ(σ,g,I,T) ≡ (σ′,μ′ ,A,o)
      def execute
        loop do
          if (@exception ||= check_exception(@state, machine_state, instruction))
            if @burn_gas_on_exception
              debug("exception: #{@exception}, burn gas #{machine_state.remain_gas} to zero")
              machine_state.consume_gas machine_state.remain_gas
            end
            return [EMPTY_SET, machine_state, SubState::EMPTY, instruction, EMPTY_SET]
          elsif get_op(machine_state.pc) == OP::REVERT
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

      private

      # O(σ, μ, A, I) ≡ (σ′, μ′, A′, I)
      def operate
        ms = machine_state
        w = get_op(ms.pc)
        operation = OP.get(w)

        raise "can't find operation #{w}, pc #{ms.pc}" unless operation

        op_cost = fork_schema.gas_of_operation(self)
        ms.consume_gas op_cost

        # call operation
        begin
          operation.call(self)
        rescue VMError => e
          @exception = e
        end

        # revert sub_state and return if exception occur
        if exception
          @sub_state = SubState::EMPTY
          return
        end

        debug("depth: #{instruction.execute_depth} pc: #{ms.pc} #{operation.name} gas: #{op_cost} stack: #{stack.size} logs: #{sub_state.log_series.size}")
        ms.pc = case
                when w == OP::JUMP
                  @jump_to
                when w == OP::JUMPI
                  @jump_to
                else
                  next_valid_instruction_pos(ms.pc, w)
                end
      end

      # determinate halt or not halt
      def halt
        w = get_op(machine_state.pc)
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
        w = instruction.get_op(ms.pc)
        case
        when w == OP::INVALID
          InvalidOpCodeError.new "can't find op code 0x#{w.to_s(16)}"
        when OP.input_count(w).nil?
          InvalidOpCodeError.new "can't find op code 0x#{w.to_s(16)}"
        when ms.stack.size < (consume = OP.input_count(w))
          StackError.new "stack not enough: stack:#{ms.stack.size} next consume: #{consume}"
        when ms.remain_gas < (gas_cost = fork_schema.gas_of_operation(self))
          GasNotEnoughError.new "gas not enough: gas remain:#{ms.remain_gas} gas cost: #{gas_cost}"
        when w == OP::JUMP && instruction.destinations.include?(ms.get_stack(0, Integer))
          InvalidJumpError.new "invalid jump dest #{ms.get_stack(0, Integer)}"
        when w == OP::JUMPI && ms.get_stack(1, Integer) != 0 && instruction.destinations.include?(ms.get_stack(0, Integer))
          InvalidJumpError.new "invalid condition jump dest #{ms.get_stack(0, Integer)}"
        when w == OP::RETURNDATACOPY && ms.get_stack(1, Integer) + ms.get_stack(2, Integer) > ms.output.size
          ReturnError.new "return data copy error"
        when stack.size - OP.input_count(w) + OP.output_count(w) > 1024
          StackError.new "stack size reach 1024 limit"
          # A condition in yellow paper but I can't understand..: (¬Iw ∧W(w,μ))
        when instruction.execute_depth > 1024
          StackError.new "call depth reach 1024 limit"
        else
          nil
        end
      end

    end
  end
end
