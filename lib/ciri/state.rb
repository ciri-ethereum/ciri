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


require 'forwardable'
require 'ciri/db/account_db'

module Ciri
  class State
    extend Forwardable

    def_delegators :@account_db, :set_nonce, :increment_nonce, :set_balance, :add_balance,
                   :find_account, :delete_account, :account_dead?, :store, :fetch,
                   :set_account_code, :get_account_code, :account_exist?

    def initialize(db, state_root: nil)
      @db = db
      @account_db = DB::AccountDB.new(db, root_hash: state_root)
    end

    def snapshot
      [state_root, @db.dup]
    end

    def revert(snapshot)
      state_root, _db = snapshot
      @account_db = DB::AccountDB.new(@db, root_hash: state_root)
    end

    def commit(snapshot)
      true
    end

    def state_root
      @account_db.root_hash
    end
  end
end
