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


require 'ciri/pow_chain/transaction'

module Ciri
  module Forks
    module Frontier
      class Transaction < POWChain::Transaction

        def validate!
          validate_sender!

          raise InvalidError.new('signature rvs error') unless signature.valid?
          raise InvalidError.new('gas_price overflow') unless UInt256.valid?(gas_price)
          raise InvalidError.new('nonce overflow') unless UInt256.valid?(nonce)
          raise InvalidError.new('gas_limit overflow') unless UInt256.valid?(gas_limit)
          raise InvalidError.new('value overflow') unless UInt256.valid?(value)

          unless v >= v_min && v <= v_max
            raise InvalidError.new("v can be only 27 or 28 in frontier schema, found: #{v}")
          end

          validate_intrinsic_gas!
        end

        def v_min
          27
        end

        def v_max
          28
        end

        def validate_intrinsic_gas!
          begin
            fork_schema = Schema.new
            intrinsic_gas = fork_schema.intrinsic_gas_of_transaction(self)
          rescue StandardError
            raise InvalidError.new 'intrinsic gas calculation error'
          end
          raise InvalidError.new 'intrinsic gas not enough' unless intrinsic_gas <= gas_limit
        end

      end
    end
  end
end