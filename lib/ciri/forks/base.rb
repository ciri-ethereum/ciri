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
  module Forks

    class Base
      # gas methods
      def gas_of_operation(vm)
        raise NotImplementedError
      end

      def gas_of_memory(word_count)
        raise NotImplementedError
      end

      def gas_of_call(vm:, gas:, to:, value:)
        raise NotImplementedError
      end

      def intrinsic_gas_of_transaction(transaction)
        raise NotImplementedError
      end

      def calculate_deposit_code_gas(code_bytes)
        raise NotImplementedError
      end

      def mining_rewards_of_block(block)
        raise NotImplementedError
      end

      def calculate_refund_gas(vm)
        raise NotImplementedError
      end

      # chain difficulty method
      def difficulty_time_factor(header, parent_header)
        raise NotImplementedError
      end

      def difficulty_virtual_height(height)
        raise NotImplementedError
      end
    end

  end
end
