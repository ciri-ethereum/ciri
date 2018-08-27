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
require_relative 'tangerine_whistle'
require_relative 'spurious_dragon/transaction'
require_relative 'spurious_dragon/cost'

module Ciri
  module Forks
    # https://github.com/ethereum/EIPs/blob/master/EIPS/eip-607.md
    module SpuriousDragon
      class Schema < Forks::TangerineWhistle::Schema

        CONTRACT_CODE_SIZE_LIMIT = 2 ** 14 + 2 ** 13

        def initialize
          super
          @cost = Cost.new
        end

        def transaction_class
          Transaction
        end

        def contract_code_size_limit
          CONTRACT_CODE_SIZE_LIMIT
        end

        def contract_init_nonce
          1
        end

        def clean_empty_accounts?
          true
        end

      end
    end
  end
end
