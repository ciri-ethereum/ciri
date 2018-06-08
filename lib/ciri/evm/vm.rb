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
        return 0 if pos >= bytes_code.size || pos + size - 1 >= bytes_code.size
        bytes_code[pos..(pos + size - 1)]
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
    SubState = Struct.new(:suicide_accounts, :log_series, :touched_accounts, :refunds, keyword_init: true)

    # represent current vm status, include stack, memory..
    MachineState = Struct.new(:gas_remain, :pc, :memory, :memory_item, :stack, :output, keyword_init: true) do

      def pop_list(count, type = nil)
        count.times.map {pop(type)}
      end

      def pop(type = nil)
        item = stack.shift
        if type == Integer && !item.is_a?(Integer)
          item = Utils.big_endian_decode(item)
        end
        item
      end

      def get_stack_item(index, type = nil)
        item = stack[index]
        if type == Integer && !item.is_a?(Integer)
          item = Utils.big_endian_decode(item)
        end
        item
      end

      # push into stack
      def push(item)
        stack.unshift(item)
      end

      # store data to memory
      def memory_store(start, size, data)
        memory[start..(start + size - 1)] = Utils.serialize(data).rjust(size, "\x00".b)
      end

      # fetch data from memory
      def fetch_memory(start, size)
        memory[start..(start + size - 1)]
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

      def_delegators :@machine_state, :stack, :pc, :pop, :push, :pop_list, :get_stack_item,
                     :memory_item, :memory_item=, :memory_store, :fetch_memory
      def_delegators :@instruction, :get_op, :get_code, :next_valid_instruction_pos, :data

      attr_reader :state, :machine_state, :instruction, :sub_state, :block_info, :fork_config
      attr_accessor :output

      def initialize(state:, machine_state:, sub_state: EMPTY_SUBSTATE, instruction:, block_info:, fork_config:)
        @state = state
        @machine_state = machine_state
        @instruction = instruction
        @sub_state = sub_state
        @output = nil
        @block_info = block_info
        @fork_config = fork_config
      end


      def store_data(address, key, data)
        # debug "address #{address} store data #{serialize data} on key #{key}"
        account = state[address] || Account.new(address: address, balance: 0, storage: {}, nonce: 0)
        return unless data && data != 0
        account.storage[key] = Utils.serialize(data).rjust(32, "\x00".b)
        state[address] = account
      end

      def fetch_data(address, key)
        # debug "address #{address} fetch data #{data} on key #{key}"
        state[address].storage[key]
      end

      def run
        # @state, @machine_state, @sub_state, @instruction, @output = execute(@state, @machine_state, @sub_state, @instruction)
        execute(@state, @machine_state, @sub_state, @instruction)
      end

      # Ξ(σ,g,I,T) ≡ (σ′,μ′ ,A,o)
      def execute(state, machine_state, sub_state, instruction)
        loop do
          if exception?(state, machine_state, instruction)
            return [EMPTY_SET, machine_state, EMPTY_SUBSTATE, instruction, EMPTY_SET]
          elsif get_op(machine_state.pc) == OP::REVERT
            o = halt(machine_state, instruction)
            gas_cost = fork_config.cost_of_operation[state, EMPTY_SUBSTATE, instruction]
            machine_state.gas_remain -= gas_cost
            return [EMPTY_SET, machine_state, sub_state, instruction, o]
          elsif (o = halt(machine_state, instruction)) != EMPTY_SET
            # STOP
            debug("#{pc} STOP gas: 0 stack: #{stack.size}")
            return [state, machine_state, sub_state, instruction, o]
          else
            operate(state, machine_state, sub_state, instruction)
            next
          end
        end
      end

      # O(σ, μ, A, I) ≡ (σ′, μ′, A′, I)
      def operate(state, ms, sub_state, instruction)
        w = get_op(ms.pc)
        operation = OP.get(w)

        raise "can't find operation #{w}, pc #{ms.pc}" unless operation

        op_cost = fork_config.cost_of_operation[state, ms, instruction]
        memory_cost = fork_config.cost_of_memory[ms.memory_item]
        # call operation
        operation.call(self)
        # calculate gas_cost
        new_memory_cost = fork_config.cost_of_memory[ms.memory_item]
        gas_cost = new_memory_cost - memory_cost + op_cost
        ms.gas_remain -= gas_cost

        debug("#{ms.pc} #{operation.name} gas: #{gas_cost} stack: #{stack.size}")
        ms.pc = case
                when w == OP::JUMP
                  @jump_to
                when w == OP::JUMPI
                  @jump_to
                else
                  next_valid_instruction_pos(ms.pc, w)
                end
      end

      # only valid if current op code is allowed to modify pc
      def jump_to(pc)
        @jump_to = pc
      end

      private

      # determinate halt or not halt
      def halt(machine_state, instruction)
        w = get_op(machine_state.pc)
        if w == OP::RETURN || w == OP::REVERT
          operate(state, machine_state, sub_state, instruction)
          output
        elsif w == OP::STOP || w == OP::SELFDESTRUCT
          # return empty sequence: nil
          nil
        else
          EMPTY_SET
        end
      end

      # check status
      def exception?(state, ms, instruction)
        w = instruction.get_op(ms.pc)
        case
        when ms.gas_remain < fork_config.cost_of_operation[state, ms, instruction]
          true
        when OP.input_count(w).nil?
          true
        when ms.stack.size < OP.input_count(w)
          true
        when w == OP::JUMP && instruction.destinations.include?(ms.stack[0])
          true
        when w == OP::JUMPI && ms.stack[1] != 0 && instruction.destinations.include?(ms.stack[0])
          true
        when w == OP::RETURNDATACOPY && ms.stack[1] + ms.stack[2] > ms.output.size
          true
        when stack.size - OP.input_count(w) + OP.output_count(w) > 1024
          true
          # A condition in yellow paper but I can't understand..: (¬Iw ∧W(w,μ))
        else
          false
        end
      end

    end
  end
end
