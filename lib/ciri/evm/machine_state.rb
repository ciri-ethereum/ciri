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
