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
require 'ciri/evm/errors'

module Ciri
  class EVM
    class ExecutionContext

      include Utils::Logger

      attr_accessor :instruction, :depth, :pc, :exception, :gas_limit, :block_info, :sub_state, :fork_schema
      attr_reader :children, :remain_gas, :machine_state

      def initialize(instruction:, depth: 0, gas_limit:, remain_gas: gas_limit, fork_schema:, pc: 0,
                     block_info:, sub_state: SubState::EMPTY.dup, machine_state: MachineState.new)
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
        @refund_gas = 0
        @machine_state = machine_state
      end

      # jump to pc
      # only valid if current op code is allowed to modify pc
      def jump_to(pc)
        # allow pc = nil to clear exist @jump_to
        unless pc.nil? || instruction.destinations.include?(pc)
          raise EVM::InvalidJumpError.new("invalid jump in runtime, pc: #{pc}")
        end
        @jump_to = pc
      end

      def jump_pc
        @jump_to
      end

      def set_exception(e)
        @exception ||= e
      end

      def set_output(output)
        @output ||= output
      end

      def output
        @output || ''.b
      end

      def set_pc(pc)
        @pc = pc
      end

      def revert
        @sub_state = SubState::EMPTY
      end

      def status
        exception.nil? ? 1 : 0
      end

      def child_context(instruction: self.instruction.dup, depth: self.depth + 1, pc: 0, gas_limit:)
        child = ExecutionContext.new(
          instruction: instruction,
          depth: depth,
          pc: pc,
          gas_limit: gas_limit,
          block_info: block_info,
          sub_state: SubState.new,
          remain_gas: gas_limit,
          fork_schema: fork_schema,
        )
        children << child
        child
      end

      def consume_gas(gas)
        raise GasNotEnoughError.new("can't consume gas to negative, remain_gas: #{remain_gas}, consumed: #{gas}") if gas > remain_gas
        debug "consume #{gas} gas, from #{@remain_gas} -> #{@remain_gas - gas}"
        @remain_gas -= gas
      end

      def return_gas(gas)
        raise ArgumentError.new("can't return negative gas, gas: #{gas}") if gas < 0
        debug "return #{gas} gas, from #{@remain_gas} -> #{@remain_gas + gas}"
        @remain_gas += gas
      end

      def reset_refund_gas
        refund_gas = @refund_gas
        @refund_gas = 0
        refund_gas
      end

      def refund_gas(gas)
        raise ArgumentError.new("gas can't be negative: #{gas}") if gas < 0
        debug "refund #{gas} gas"
        @refund_gas += gas
      end

      # used gas of context
      def used_gas
        @gas_limit - @remain_gas
      end

      def all_log_series
        sub_state.log_series + children.map {|c| c.all_log_series}.flatten
      end

      def all_suicide_accounts
        (sub_state.suicide_accounts + children.map {|c| c.all_suicide_accounts}.flatten).uniq(&:to_s)
      end

    end
  end
end
