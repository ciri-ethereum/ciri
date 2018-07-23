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


require 'ciri/evm/errors'

module Ciri
  class EVM
    class ExecutionContext

      attr_accessor :instruction, :depth, :pc, :output, :exception, :gas_limit, :block_info, :sub_state, :fork_schema
      attr_reader :children

      def initialize(instruction:, depth: 1, gas_limit:, remain_gas: gas_limit, fork_schema:, pc: 0,
                     block_info:, sub_state: SubState::EMPTY.dup)
        raise ArgumentError.new("remain_gas must more than 0") if remain_gas < 0
        raise ArgumentError.new("gas_limit must more than 0") if gas_limit < 0

        @instruction = instruction
        @depth = depth
        @gas_limit = gas_limit
        @block_info = block_info
        @sub_state = sub_state
        @remain_gas = remain_gas
        @fork_schema = fork_schema
        @pc = pc
        @children = []
      end

      def set_exception(e)
        @exception ||= e
      end

      def set_output(output)
        @output ||= output
      end

      def set_pc(pc)
        @pc = pc
      end

      def revert
        @sub_state = SubState::EMPTY
      end

      def status
        exception.nil? ? 0 : 1
      end

      def child_context(instruction: self.instruction.dup, depth: self.depth + 1, pc: 0, gas_limit:)
        child = ExecutionContext.new(
          instruction: instruction,
          depth: depth,
          pc: pc,
          gas_limit: gas_limit,
          block_info: block_info,
          sub_state: sub_state.dup,
          remain_gas: gas_limit,
          fork_schema: fork_schema,
        )
        children << child
        child
      end

      def consume_gas(gas)
        raise GasNotEnoughError.new("can't consume gas to negative, remain_gas: #{remain_gas}, consumed: #{gas}") if gas > remain_gas
        @remain_gas -= gas
      end

      # used gas of context
      def used_gas
        @gas_limit - @remain_gas
      end

      # remain gas of context
      def remain_gas
        @remain_gas - children.reduce(0) {|s, c| s + c.used_gas}
      end

      def all_log_series
        sub_state.log_series + children.map {|c| c.all_log_series}.flatten
      end

    end
  end
end
