# frozen_string_literal: true

# Copyright (c) 2018 by Jiang Jinyang <jjyruby@gmail.com>
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


require_relative 'base'
require_relative 'frontier'
require_relative 'homestead/transaction'
require_relative 'homestead/opcodes'

module Ciri
  module Forks
    # Homestead fork
    # https://github.com/ethereum/EIPs/blob/master/EIPS/eip-606.md
    module Homestead
      class Schema < Forks::Frontier::Schema

        include Forks::Frontier

        def initialize(support_dao_fork:)
          @support_dao_fork = support_dao_fork
          super()
        end

        def intrinsic_gas_of_transaction(t)
          gas = (t.data.each_byte || '').reduce(0) {|sum, i| sum + (i.zero? ? Cost::G_TXDATAZERO : Cost::G_TXDATANONZERO)}
          gas + (t.to.empty? ? Cost::G_TXCREATE : 0) + Cost::G_TRANSACTION
        end

        def calculate_difficulty(header, parent_header)
          # https://github.com/ethereum/EIPs/blob/984cf5de90bbf5fbe7e49be227b0c2f9567e661e/EIPS/eip-2.md
          difficulty_time_factor = [1 - (header.timestamp - parent_header.timestamp) / 10, -99].max
          x = parent_header.difficulty / 2048

          # difficulty bomb
          height = header.number
          height_factor = 2 ** (height / 100000 - 2)

          difficulty = (parent_header.difficulty + x * difficulty_time_factor + height_factor).to_i
          [header.difficulty, difficulty].max
        end

        def transaction_class
          Transaction
        end

        def get_operation(op)
          OPCODES[op]
        end

        def exception_on_deposit_code_gas_not_enough
          true
        end

      end
    end
  end
end
