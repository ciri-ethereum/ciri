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


require 'forwardable'
require 'ciri/db/account_db'

module Ciri
  class EVM
    class State

      extend Forwardable

      def_delegators :@account_db, :set_nonce, :increment_nonce, :set_balance, :add_balance, :touch_account,
                     :find_account, :delete_account, :account_dead?, :store, :fetch, :set_account_code, :get_account_code

      def initialize(db, state_root: nil)
        @db = db
        @account_db = DB::AccountDB.new(db, root_hash: state_root)
      end

      def snapshot
        [state_root, @db.dup]
      end

      def revert(snapshot)
        state_root, db = snapshot
        @db = db
        @account_db = DB::AccountDB.new(db, root_hash: state_root)
      end

      def commit(snapshot)
        true
      end

      def state_root
        @account_db.root_hash
      end

    end
  end
end
