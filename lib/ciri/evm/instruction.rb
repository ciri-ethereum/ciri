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
  class EVM

    # represent instruction
    Instruction = Struct.new(:address, :origin, :price, :data, :sender, :value, :bytes_code, :header, :execute_depth,
                             keyword_init: true) do

      def initialize(*args)
        super
        self.data ||= ''.b
        self.value ||= 0
        self.bytes_code ||= ''.b
        self.execute_depth ||= 0
      end

      def get_op(pos)
        code_size = (bytes_code || ''.b).size
        return OP::STOP if pos == code_size
        return OP::INVALID if pos >= code_size
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
          if i > bytes_code.size
            break
          elsif bytes_code[i] == OP::JUMPDEST
            destinations << i
          end
          i = next_valid_instruction_pos(i, bytes_code[i])
        end
        destinations
      end

    end

  end
end
