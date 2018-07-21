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


require_relative 'base'
require_relative 'frontier'

module Ciri
  module Forks
    module Homestead
      class Schema < Forks::Frontier::Schema

        include Forks::Frontier::Cost

        def initialize(support_dao_fork:)
          @support_dao_fork = support_dao_fork
        end

        def intrinsic_gas_of_transaction(t)
          gas = (t.data.each_byte || '').reduce(0) {|sum, i| sum + (i.zero? ? G_TXDATAZERO : G_TXDATANONZERO)}
          gas + (t.to.empty? ? G_TXCREATE : 0) + G_TRANSACTION
        end

        # chain difficulty method
        # https://github.com/ethereum/EIPs/blob/984cf5de90bbf5fbe7e49be227b0c2f9567e661e/EIPS/eip-2.md
        def difficulty_time_factor(header, parent_header)
          [1 - (header.timestamp - parent_header.timestamp) / 10, -99].max
        end

      end
    end
  end
end
