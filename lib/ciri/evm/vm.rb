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
    # defined in yellow paper
    Instruction = Struct.new(:address, :origin, :price, :data, :sender, :value, :bytes_code, :header, :execute_depth, :w,
                             keyword_init: true)
    SubState = Struct.new(:suicide_accounts, :log_series, :touched_accounts, :refunds, keyword_init: true)
    MachineState = Struct.new(:gas_remain, :pc, :memory, :active_number, :stack, :output, keyword_init: true)

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

      def_delegators :@machine_state, :stack, :pc

      attr_reader :state, :machine_state, :instruction, :sub_state, :output

      def initialize(state:, machine_state:, sub_state: EMPTY_SUBSTATE, instruction:)
        @state = state
        @machine_state = machine_state
        @instruction = instruction
        @sub_state = sub_state
        @output = nil
      end

      def pop_list(count, type)
        count.times.map do
          pop(type)
        end
      end

      def pop(type = nil)
        item = stack.pop
        item = if type == Integer
                 item.is_a?(Integer) ? item : Utils.big_endian_decode(item)
               else
                 item
               end
        debug("pop item #{item.inspect}")
        item
      end

      # push into stack
      def push(item)
        debug("push item #{item.inspect}")
        stack.push(item)
      end

      # get data from instruction
      def get_code(pos, size = 1)
        return 0 if pos >= @instruction.bytes_code.size || pos + size - 1 >= @instruction.bytes_code.size
        @instruction.bytes_code[pos..(pos + size - 1)]
      end


      def store_data(address, key, data)
        p "address #{address} store data #{serialize data} on key #{key}"
        state[address].storage[key] = serialize data
      end

      def fetch_data(address, key, data)
        p "address #{address} fetch data #{data} on key #{key}"
        state[address].storage[key]
      end

      def run
        @state, @machine_state, @instruction, @sub_state, @output = execute(@state, @machine_state, @instruction, @sub_state)
      end

      # Ξ(σ,g,I,T) ≡ (σ′,μ′ ,A,o)
      def execute(state, machine_state, sub_state, instruction)
        loop do
          if false && exception?(state, machine_state, instruction)
            return [EMPTY_SET, machine_state, EMPTY_SUBSTATE, instruction, EMPTY_SET]
          elsif get_op(machine_state.pc) == OP::REVERT
            o = halt(machine_state, instruction)
            gas_cost = Cost.cost(state, EMPTY_SUBSTATE, instruction)
            ms1 = machine_state.dup
            ms1.gas_remain - gas_cost
            return [EMPTY_SET, ms1, sub_state, instruction, o]
          elsif (o = halt(machine_state, instruction)) != EMPTY_SET
            # STOP
            return [state, machine_state, sub_state, instruction, o]
          else
            operate(state, machine_state, sub_state, instruction)
            next
          end
        end
      end

      # O(σ, μ, A, I) ≡ (σ′, μ′, A′, I)
      def operate(state, ms, sub_state, instruction)
        ms.gas_remain - Cost.cost(state, sub_state, instruction)
        w = get_op(ms.pc)
        operation = OP.get(w)
        raise "can't find operation #{w}, pc #{ms.pc}" unless operation
        debug("#{ms.pc} #{operation.name}")
        operation.call(self, instruction)
        ms.pc = case
                when w == OP::JUMP
                  # jump
                when w == OP::JUMPI
                  #JUMPI
                else
                  next_valid_instruction_pos(ms.pc, w)
                end
      end

      private

      # get operation code
      def get_op(pos)
        return 0 if pos >= @instruction.bytes_code.size
        @instruction.bytes_code[pos].ord
      end

      # determinate halt or not halt
      def halt(machine_state, instruction)
        w = get_op(machine_state.pc)
        if w == OP::RETURN || w == OP::REVERT
          #TODO actually return? should update machine_state?
          [OP::RETURN, machine_state]
        elsif w == OP::STOP || w == OP::SELFDESTRUCT
          # return empty sequence: nil
          nil
        else
          EMPTY_SET
        end
      end

      # check status
      def exception?(state, ms, instruction)
        w = instruction.op(ms.pc)
        case
        when ms.gas_remain < Cost.cost(state, ms, instruction)
          true
        when OP.input_count(w).nil?
          true
        when ms.stack.size < OP.input_count(w)
          true
        when w == OP::JUMP && destinations(instruction.bytes_code).include?(ms.stack[0])
          true
        when w == OP::JUMPI && ms.stack[1] != 0 && destinations(instruction.bytes_code).include?(ms.stack[0])
          true
        when w == OP::RETURNDATACOPY && ms.stack[1] + ms.stack[2] > ms.output.size
          true
        when instruction.stack.size - OP.input_count(w) + OP.output_count(w) > 1024
          true
          # A condition in yellow paper but I can't understand..: (¬Iw ∧W(w,μ))
        else
          false
        end
      end

      def destinations(bytes_code)
        destinations_by_index(bytes_code, 0)
      end

      def destinations_by_index(bytes_code, i)
        if i > bytes_code.size
          []
        elsif bytes_code[i] == OP::JUMPDEST
          [i] + destinations_by_index(bytes_code, next_valid_instruction_pos(i, bytes_code[i]))
        else
          destinations_by_index(bytes_code, next_valid_instruction_pos(i, bytes_code[i]))
        end
      end

      def next_valid_instruction_pos(i, w)
        if (OP::PUSH1..OP::PUSH32).include?(w)
          i + w - OP::PUSH1 + 2
        else
          i + 1
        end
      end


      def serialize(item)
        case item
        when Integer
          Utils.big_endian_encode(item)
        else
          item
        end
      end

    end
  end
end
