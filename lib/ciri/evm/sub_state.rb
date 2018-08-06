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
