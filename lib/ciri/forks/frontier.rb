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


require 'ciri/evm/forks/frontier'

module Ciri
  module Forks
    module Frontier

      class << self
        def fork_config
          ForkConfig.new(
            cost_of_operation: proc {|vm| EVM::Forks::Frontier::Cost.cost_of_operation vm},
            cost_of_memory: proc {|i| EVM::Forks::Frontier::Cost.cost_of_memory i},
            intrinsic_gas_of_transaction: proc {|t| EVM::Forks::Frontier::Cost.intrinsic_gas_of_transaction t},
            transaction_fee_gas: EVM::Forks::Frontier::Cost::G_TRANSACTION,
          )
        end
      end

    end
  end
end
