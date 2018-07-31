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
require 'ciri/serialize'
require 'ciri/evm/errors'

module Ciri
  class EVM

    # represent current vm status, include stack, memory..
    class MachineState
      include Utils::Logger

      attr_reader :memory, :stack

      def initialize(memory: ''.b, stack: [])
        @memory = memory
        @stack = stack
      end

      # fetch a list of items from stack
      def pop_list(count, type = nil)
        count.times.map {pop(type)}
      end

      # pop a item from stack
      def pop(type = nil)
        item = stack.shift
        item && Serialize.deserialize(type, item)
      end

      # get item from stack
      def get_stack(index, type = nil)
        item = stack[index]
        item && Serialize.deserialize(type, item)
      end

      # push into stack
      def push(item)
        stack.unshift(item)
      end

      # store data to memory
      def memory_store(start, size, data)
        if size > 0 && start < memory.size && start + size - 1 < memory.size
          memory[start..(start + size - 1)] = Serialize.serialize(data).rjust(size, "\x00".b)
        end
      end

      # fetch data from memory
      def memory_fetch(start, size)
        if size > 0 && start < memory.size && start + size - 1 < memory.size
          memory[start..(start + size - 1)]
        else
          # prevent size is too large
          "\x00".b * [size, memory.size].min
        end
      end

      def memory_item
        Utils.ceil_div(memory.size, 32)
      end

      # extend vm memory, used for memory_gas calculation
      def extend_memory(context, pos, size)
        if size != 0 && (new_item = Utils.ceil_div(pos + size, 32)) > memory_item
          debug("extend memory: from #{memory_item} -> #{new_item}")
          old_cost_gas = context.fork_schema.gas_of_memory memory_item
          new_cost_gas = context.fork_schema.gas_of_memory new_item
          context.consume_gas(new_cost_gas - old_cost_gas)

          extend_size = (new_item - memory_item) * 32
          self.memory << "\x00".b * extend_size
        end
      end

    end

  end
end
