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


module Ciri
  module EVM

    #### VM States, defined in yellow paper
    # represent instruction
    Instruction = Struct.new(:address, :origin, :price, :data, :sender, :value, :bytes_code, :header, :execute_depth,
                             keyword_init: true) do

      def get_op(pos)
        return 0 if pos >= bytes_code.size
        bytes_code[pos].ord
      end

      # get data from instruction
      def get_code(pos, size = 1)
        if size > 0 && pos < bytes_code.size && pos + size - 1 < bytes_code.size
          bytes_code[pos..(pos + size - 1)]
        else
          "\x00".b * size
        end
      end

      def get_data(pos, size)
        if pos < data.size && size > 0
          data[pos..(pos + size - 1)].ljust(size, "\x00".b)
        else
          "\x00".b * size
        end
      end

      # valid destinations of bytes_code
      def destinations
        @destinations ||= destinations_by_index(bytes_code, 0)
      end

      def next_valid_instruction_pos(pos, op_code)
        if (OP::PUSH1..OP::PUSH32).include?(op_code)
          pos + op_code - OP::PUSH1 + 2
        else
          pos + 1
        end
      end

      private

      def destinations_by_index(bytes_code, i)
        if i > bytes_code.size
          []
        elsif bytes_code[i] == OP::JUMPDEST
          [i] + destinations_by_index(bytes_code, next_valid_instruction_pos(i, bytes_code[i]))
        else
          destinations_by_index(bytes_code, next_valid_instruction_pos(i, bytes_code[i]))
        end
      end

    end

    # sub state contained changed accounts and log_series
    class SubState
      attr_reader :suicide_accounts, :log_series, :touched_accounts, :refunds

      def initialize(suicide_accounts: [], log_series: [], touched_accounts: [], refunds: [])
        @suicide_accounts = suicide_accounts
        @log_series = log_series
        @touched_accounts = touched_accounts
        @refunds = refunds
      end
    end

    # represent current vm status, include stack, memory..
    MachineState = Struct.new(:gas_remain, :pc, :memory, :memory_item, :stack, :output, keyword_init: true) do

      # fetch a list of items from stack
      def pop_list(count, type = nil)
        count.times.map {pop(type)}
      end

      # pop a item from stack
      def pop(type = nil)
        item = stack.shift
        item && Utils.deserialize(type, item)
      end

      # get item from stack
      def get_stack(index, type = nil)
        item = stack[index]
        item && Utils.deserialize(type, item)
      end

      # push into stack
      def push(item)
        stack.unshift(item)
      end

      # store data to memory
      def memory_store(start, size, data)
        if start < memory.size && start + size - 1 < memory.size
          memory[start..(start + size - 1)] = Utils.serialize(data).rjust(size, "\x00".b)
        end
      end

      # fetch data from memory
      def memory_fetch(start, size)
        if size > 0 && start < memory.size && start + size - 1 < memory.size
          memory[start..(start + size - 1)]
        else
          "\x00".b * size
        end
      end

      # extend vm memory, used for memory_gas calculation
      def extend_memory(pos, size)
        if size != 0 && (i = Utils.ceil_div(pos + size, 32)) > memory_item
          self.memory_item = i
        end
      end

    end

    # Block Info
    BlockInfo = Struct.new(:coinbase, :difficulty, :gas_limit, :number, :timestamp, keyword_init: true)

    # Fork configure
    ForkConfig = Struct.new(:cost_of_operation, :cost_of_memory, keyword_init: true)

    # represent empty set, distinguished with nil
    EMPTY_SET = [].freeze
    EMPTY_SUBSTATE = SubState.new.freeze

    # EVM
    # Here include batch constants(OP, Cost..) you can find there definition in Ethereum yellow paper.
    # If you can't understand some mystery formula in comments... go to read Ethereum yellow paper.
    #
    # VM 'immutable style':
    # for making VM implementation according to the 'Ethereum yellow paper' expression,
    # we use 'immutable style' to design our VM:
    #
    # 1. pass vm states as arguments rather than using instance variables
    # 2. mostly methods should not cause side effect, using dup instead directly update object
    #
    class VM
      extend Forwardable
      include Utils::Logger

      def_delegators :@machine_state, :stack, :pc, :pop, :push, :pop_list, :get_stack,
                     :memory_item, :memory_item=, :memory_store, :memory_fetch, :extend_memory
      def_delegators :@instruction, :get_op, :get_code, :next_valid_instruction_pos, :get_data, :data

      attr_reader :machine_state, :instruction, :sub_state, :block_info, :fork_config
      attr_accessor :output

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
        key = key.gsub(/\A\0+(?=.)/, ''.b)
        account = @state[address] || Account.new(address: address, balance: 0, storage: {}, nonce: 0)
        account.storage[key] = Utils.serialize(data).rjust(32, "\x00".b)
        @state[address] = account
      end

      # fetch data from address
      def fetch(address, key)
        @state[address].storage[key] || ''.b
      end

      # run vm
      def run
        execute
      end

      # jump to pc
      # only valid if current op code is allowed to modify pc
      def jump_to(pc)
        @jump_to = pc
      end

      def account_dead?(address)
        account = @state[address]
        account.nil? || account.empty?
      end

      def find_account(address)
        @state[address] || Account.new_empty(address)
      end

      def update_account(address, account)
        @state[address] = account unless account.empty?
      end

      private

      # Execute instruction with states
      # Ξ(σ,g,I,T) ≡ (σ′,μ′ ,A,o)
      def execute
        loop do
          if (err = check_exception(@state, machine_state, instruction))
            debug("exception: #{err}")
            return [EMPTY_SET, machine_state, EMPTY_SUBSTATE, instruction, EMPTY_SET]
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

      # O(σ, μ, A, I) ≡ (σ′, μ′, A′, I)
      def operate
        ms = machine_state
        w = get_op(ms.pc)
        operation = OP.get(w)

        raise "can't find operation #{w}, pc #{ms.pc}" unless operation

        op_cost = fork_config.cost_of_operation[self]
        old_memory_cost = fork_config.cost_of_memory[ms.memory_item]
        ms.gas_remain -= op_cost
        # call operation
        operation.call(self)
        # calculate gas_cost
        new_memory_cost = fork_config.cost_of_memory[ms.memory_item]
        memory_gas_cost = new_memory_cost - old_memory_cost
        ms.gas_remain -= memory_gas_cost

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
          "can't find op code #{w}"
        when ms.stack.size < (consume = OP.input_count(w))
          "stack not enough: stack:#{ms.stack.size} next consume: #{consume}"
        when ms.gas_remain < (gas_cost = fork_config.cost_of_operation[self])
          "gas not enough: gas remain:#{ms.gas_remain} gas cost: #{gas_cost}"
        when w == OP::JUMP && instruction.destinations.include?(ms.get_stack(0, Integer))
          "invalid jump dest #{ms.get_stack(0, Integer)}"
        when w == OP::JUMPI && ms.get_stack(1, Integer) != 0 && instruction.destinations.include?(ms.get_stack(0, Integer))
          "invalid condition jump dest #{ms.get_stack(0, Integer)}"
        when w == OP::RETURNDATACOPY && ms.get_stack(1, Integer) + ms.get_stack(2, Integer) > ms.output.size
          "return data copy error"
        when stack.size - OP.input_count(w) + OP.output_count(w) > 1024
          "stack size reach 1024 limit"
          # A condition in yellow paper but I can't understand..: (¬Iw ∧W(w,μ))
        else
          nil
        end
      end

    end
  end
end
