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


require 'ciri/types/address'

module Ciri
  class EVM
    # handle EVM call operations
    module OPCall
      class Base

        include Types

        def call(vm)
          raise NotImplementedError
        end

        def extract_call_argument(vm)
          gas = vm.pop(Integer)
          to = vm.pop(Address)
          value = vm.pop(Integer)
          input_mem_pos, input_size = vm.pop_list(2, Integer)
          output_mem_pos, output_mem_size = vm.pop_list(2, Integer)

          # extend input output memory
          vm.extend_memory(input_mem_pos, input_size)
          vm.extend_memory(output_mem_pos, output_mem_size)

          data = vm.memory_fetch(input_mem_pos, input_size)
          [gas, to, value, data, output_mem_pos, output_mem_size]
        end

        def call_message(vm:, gas:, sender:, value:, data:, to:, code_address: to, output_mem_pos:, output_mem_size:)
          context = vm.execution_context
          child_gas_limit, child_gas_fee = context.fork_schema.gas_of_call(vm: vm,
                                                                           gas: gas, to: to, value: value)
          context.consume_gas(child_gas_fee)
          if context.depth + 1 > 1024
            context.return_gas(child_gas_limit)
            vm.push 0
            return
          end
          child_context = context.child_context(gas_limit: child_gas_limit)
          child_context.instruction.sender = sender
          child_context.instruction.value = value
          child_context.instruction.data = data
          child_context.instruction.address = to
          child_context.instruction.bytes_code = vm.state.get_account_code(code_address)
          status, output = vm.call_message(code_address: code_address, context: child_context)

          context.return_gas(child_context.remain_gas)
          output_size = [output_mem_size, output.size].min
          vm.extend_memory(output_mem_pos, output_size)
          vm.memory_store(output_mem_pos, output_size, output)
          vm.push status
        end
      end

      class Call < Base
        def call(vm)
          gas, to, value, data, output_mem_pos, output_mem_size = extract_call_argument(vm)
          call_message(vm: vm, sender: vm.instruction.address, value: value, gas: gas, to: to,
                       data: data, code_address: to, output_mem_pos: output_mem_pos, output_mem_size: output_mem_size)
        end
      end

      class CallCode < Base
        def call(vm)
          gas, to, value, data, output_mem_pos, output_mem_size = extract_call_argument(vm)
          call_message(vm: vm, sender: vm.instruction.address, value: value, gas: gas, to: vm.instruction.address,
                       data: data, code_address: to, output_mem_pos: output_mem_pos, output_mem_size: output_mem_size)
        end
      end

      class DelegateCall < Base
        def call(vm)
          gas, to, data, output_mem_pos, output_mem_size = extract_call_argument(vm)
          call_message(vm: vm, sender: vm.instruction.sender, value: vm.instruction.value, gas: gas,
                       to: vm.instruction.address, data: data, code_address: to,
                       output_mem_pos: output_mem_pos, output_mem_size: output_mem_size)
        end

        def extract_call_argument(vm)
          gas = vm.pop(Integer)
          to = vm.pop(Address)
          input_mem_pos, input_size = vm.pop_list(2, Integer)
          output_mem_pos, output_mem_size = vm.pop_list(2, Integer)

          # extend input output memory
          vm.extend_memory(input_mem_pos, input_size)
          vm.extend_memory(output_mem_pos, output_mem_size)

          data = vm.memory_fetch(input_mem_pos, input_size)
          [gas, to, data, output_mem_pos, output_mem_size]
        end
      end

    end
  end
end
