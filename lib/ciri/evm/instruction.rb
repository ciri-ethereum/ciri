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


module Ciri
  class EVM

    # represent instruction
    Instruction = Struct.new(:address, :origin, :price, :data, :sender, :value, :bytes_code,
                             :header, keyword_init: true) do

      def initialize(*args)
        super
        self.data ||= ''.b
        self.value ||= 0
        self.bytes_code ||= ''.b
      end

      def get_op(pos)
        code_size = (bytes_code || ''.b).size
        return OP::STOP if pos >= code_size
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
        destinations = []
        loop do
          if i >= bytes_code.size
            break
          elsif bytes_code[i].bytes[0] == OP::JUMPDEST
            destinations << i
          end
          i = next_valid_instruction_pos(i, bytes_code[i].bytes[0])
        end
        destinations
      end

    end

  end
end
