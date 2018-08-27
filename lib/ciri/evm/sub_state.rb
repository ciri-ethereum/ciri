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


module Ciri
  class EVM

    # sub state contained changed accounts and log_series
    class SubState

      attr_reader :suicide_accounts, :log_series, :touched_accounts, :refunds

      def initialize(suicide_accounts: [], log_series: [], touched_accounts: [], refunds: [])
        @suicide_accounts = suicide_accounts
        @log_series = log_series
        @touched_accounts = touched_accounts
        @refunds = refunds
      end

      EMPTY = SubState.new.freeze

      # support safety copy
      def initialize_copy(orig)
        super
        @suicide_accounts = orig.suicide_accounts.dup
        @log_series = orig.log_series.dup
        @touched_accounts = orig.touched_accounts.dup
        @refunds = orig.refunds.dup
      end

      def add_refund_account(address)
        @refunds << address
      end

      def add_touched_account(address)
        @touched_accounts << address
      end

      def add_suicide_account(address)
        @suicide_accounts << address
      end
    end

  end
end
