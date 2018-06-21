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


require_relative 'machine_state'
require_relative 'instruction'
require_relative 'sub_state'
require_relative 'block_info'
require_relative 'serialize'

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

      class VMError < StandardError
      end
      class InvalidOpCodeError < VMError
      end
      class GasNotEnoughError < VMError
      end
      class StackError < VMError
      end
      class InvalidJumpError < VMError
      end
      class ReturnError < VMError
      end

      class << self
        # this method provide a simpler interface to create VM and execute code
        # VM.spawn(...) == VM.new(...)
        # @return VM
        def spawn(state:, gas_limit:, header: nil, block_info: nil, instruction:, fork_config:)
          ms = MachineState.new(gas_remain: gas_limit, pc: 0, stack: [], memory: "\x00".b * 256, memory_item: 0)

          block_info = block_info || header && BlockInfo.new(
            coinbase: header.beneficiary,
            difficulty: header.difficulty,
            gas_limit: header.gas_limit,
            number: header.number,
            timestamp: header.timestamp
          )

          vm = VM.new(
            state: state,
            machine_state: ms,
            block_info: block_info,
            instruction: instruction,
            fork_config: fork_config
          )
          yield vm if block_given?
          vm
        end
      end

      extend Forwardable

      # helper methods
      include Utils::Logger
      include Serialize

      def_delegators :@machine_state, :stack, :pc, :pop, :push, :pop_list, :get_stack,
                     :memory_item, :memory_item=, :memory_store, :memory_fetch, :extend_memory
      def_delegators :@instruction, :get_op, :get_code, :next_valid_instruction_pos, :get_data, :data, :sender
      def_delegators :@sub_state, :add_refund_account, :add_touched_account, :add_suicide_account

      attr_reader :machine_state, :instruction, :sub_state, :block_info, :fork_config
      attr_accessor :output, :exception

      def initialize(state:, machine_state:, sub_state: nil, instruction:, block_info:, fork_config:)
        @state = state
        @machine_state = machine_state
        @instruction = instruction
        @sub_state = sub_state || SubState.new
        @output = nil
        @block_info = block_info
        @fork_config = fork_config
      end

      # store data to address
      def store(address, key, data)
        data_is_blank = Ciri::Utils.blank_binary?(data)
        # key_is_blank = Ciri::Utils.blank_binary?(key)

        return unless data && !data_is_blank

        # remove unnecessary null byte from key
        key = serialize(key).gsub(/\A\0+/, ''.b)
        key = "\x00".b if key.empty?

        account = find_account address
        account.storage[key] = serialize(data).rjust(32, "\x00".b)
        update_account(account)
      end

      # fetch data from address
      def fetch(address, key)
        # remove unnecessary null byte from key
        key = serialize(key).gsub(/\A\0+/, ''.b)
        key = "\x00".b if key.empty?

        find_account(address).storage[key] || ''.b
      end

      # run vm
      def run(ignore_exception: false)
        execute
        raise exception unless ignore_exception || exception.nil?
      end

      # low_level create_contract interface
      # CREATE_CONTRACT op is based on this method
      def create_contract(value:, init:)
        account = find_account(instruction.address)

        # return contract address 0 represent execution failed
        return 0 unless account.balance >= value || instruction.execute_depth > 1024

        account.nonce += 1

        # generate contract_address
        material = RLP.encode_simple([instruction.address.to_s, account.nonce - 1])
        contract_address = Utils.sha3(material)[-20..-1]

        # initialize contract account
        contract_account = find_account(contract_address)
        contract_account.nonce = 1
        contract_account.code = Utils::BLANK_SHA3

        # execute initialize code
        create_contract_instruction = instruction.dup
        create_contract_instruction.bytes_code = init
        create_contract_instruction.execute_depth += 1
        create_contract_instruction.address = contract_address

        with_new_instruction(create_contract_instruction) do
          execute
        end

        if exception
          update_account(Account.new_empty(contract_address))
          contract_address = 0
        else
          # set contract code
          contract_account.code = output || ''.b
          # transact value
          account.balance -= value
          contract_account.balance += value
        end

        # update account
        update_account(contract_account)
        update_account(account)

        contract_address
      end

      # low level call message interface
      # CALL, CALLCODE, DELEGATECALL ops is base on this method
      def call_message(sender:, value:, receipt:, data:, code_address:)
        # return status code 0 represent execution failed
        return [0, ''.b] unless value <= find_account(instruction.address).balance && instruction.execute_depth < 1024

        call_instruction = instruction.dup
        call_instruction.address = receipt
        call_instruction.sender = sender
        call_instruction.value = value

        call_instruction.execute_depth += 1

        call_instruction.data = data
        call_instruction.bytes_code = find_account(code_address).code || ''.b

        transact(sender: sender, value: value, to: receipt)

        with_new_instruction(call_instruction) do
          execute
        end

        status = exception.nil? ? 0 : 1
        [status, output || ''.b]
      end

      # jump to pc
      # only valid if current op code is allowed to modify pc
      def jump_to(pc)
        @jump_to = pc
      end

      def account_dead?(address)
        Account.account_dead?(@state, address)
      end

      def find_account(address)
        Account.find_account(@state, address)
      end

      # the only method which touch state
      # VM do not consider state revert/commit, we let it to state implementation
      def update_account(account)
        address = account.address.to_s
        @state[address] = account
        add_touched_account(account)
      end

      def add_log_entry(topics, log_data)
        sub_state.log_series << [instruction.address, topics, log_data]
      end

      # transact value from sender to target address
      def transact(sender:, value:, to:)
        sender = find_account(sender)
        to = find_account(to)

        raise VMError.new("balance not enough") if sender.balance < value

        sender.balance -= value
        to.balance += value

        update_account(sender)
        update_account(to)
      end

      def with_new_instruction(new_instruction)
        origin_instruction = instruction
        @instruction = new_instruction
        yield
        @instruction = origin_instruction
      end

      # Execute instruction with states
      # Ξ(σ,g,I,T) ≡ (σ′,μ′ ,A,o)
      def execute
        loop do
          if (@exception = check_exception(@state, machine_state, instruction))
            debug("exception: #{@exception}")
            return [EMPTY_SET, machine_state, SubState::EMPTY, instruction, EMPTY_SET]
          elsif get_op(machine_state.pc) == OP::REVERT
            o = halt
            gas_cost = fork_config.cost_of_operation[self]
            machine_state.gas_remain -= gas_cost
            return [EMPTY_SET, machine_state, sub_state, instruction, o]
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

        op_cost = fork_config.cost_of_operation[self]
        old_memory_cost = fork_config.cost_of_memory[ms.memory_item]
        ms.gas_remain -= op_cost

        prev_sub_state = sub_state.dup

        # call operation
        operation.call(self)
        # calculate gas_cost
        new_memory_cost = fork_config.cost_of_memory[ms.memory_item]
        memory_gas_cost = new_memory_cost - old_memory_cost

        if ms.gas_remain >= memory_gas_cost
          ms.gas_remain -= memory_gas_cost
        else
          # memory gas_not_enough revert sub_state
          @sub_state = prev_sub_state
          @exception = GasNotEnoughError.new "gas not enough: gas remain:#{ms.gas_remain} gas cost: #{memory_gas_cost}"
        end

        debug("#{ms.pc} #{operation.name} gas: #{op_cost + memory_gas_cost} stack: #{stack.size}")
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
        when OP.input_count(w).nil?
          InvalidOpCodeError.new "can't find op code #{w}"
        when ms.stack.size < (consume = OP.input_count(w))
          StackError.new "stack not enough: stack:#{ms.stack.size} next consume: #{consume}"
        when ms.gas_remain < (gas_cost = fork_config.cost_of_operation[self])
          GasNotEnoughError.new "gas not enough: gas remain:#{ms.gas_remain} gas cost: #{gas_cost}"
        when w == OP::JUMP && instruction.destinations.include?(ms.get_stack(0, Integer))
          InvalidJumpError.new "invalid jump dest #{ms.get_stack(0, Integer)}"
        when w == OP::JUMPI && ms.get_stack(1, Integer) != 0 && instruction.destinations.include?(ms.get_stack(0, Integer))
          InvalidJumpError.new "invalid condition jump dest #{ms.get_stack(0, Integer)}"
        when w == OP::RETURNDATACOPY && ms.get_stack(1, Integer) + ms.get_stack(2, Integer) > ms.output.size
          ReturnError.new "return data copy error"
        when stack.size - OP.input_count(w) + OP.output_count(w) > 1024
          StackError.new "stack size reach 1024 limit"
          # A condition in yellow paper but I can't understand..: (¬Iw ∧W(w,μ))
        else
          nil
        end
      end

    end
  end
end
