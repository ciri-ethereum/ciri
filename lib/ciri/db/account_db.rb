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


require 'ciri/core_ext'
require 'ciri/trie'
require 'ciri/types/account'
require 'ciri/serialize'
require 'ciri/utils/logger'

using Ciri::CoreExt

module Ciri
  module DB
    class AccountDB

      include Serialize
      include Utils::Logger

      attr_reader :db

      def initialize(db, root_hash: nil)
        @db = db
        root_hash ||= Trie::BLANK_NODE_HASH
        @trie = Trie.new(db: @db, root_hash: root_hash, prune: false)
      end

      def root_hash
        @trie.root_hash
      end

      def store(address, key, value)
        account = find_account address
        trie = Trie.new(db: @db, root_hash: account.storage_root)

        converted_key = convert_key Utils.big_endian_encode(key, size: 32)

        if value && value != 0
          trie[converted_key] = RLP.encode(value)
        else
          trie.delete(converted_key)
        end
        account.storage_root = trie.root_hash
        update_account(address, account)
      end

      def fetch(address, key)
        # remove unnecessary null byte from key
        converted_key = convert_key Utils.big_endian_encode(key, size: 32)
        account = find_account address
        trie = Trie.new(db: @db, root_hash: account.storage_root)
        value = trie[converted_key]
        value.empty? ? 0 : RLP.decode(value, Integer)
      end

      def set_nonce(address, nonce)
        account = find_account(address)
        account.nonce = nonce
        update_account(address, account)
      end

      def increment_nonce(address, value = 1)
        account = find_account(address)
        account.nonce += value
        update_account(address, account)
      end

      def set_balance(address, balance)
        account = find_account(address)
        account.balance = balance
        update_account(address, account)
      end

      def add_balance(address, value)
        account = find_account(address)
        account.balance += value
        raise "value can't be negative" if account.balance < 0
        update_account(address, account)
      end

      def set_account_code(address, code)
        code ||= ''.b
        account = find_account(address)
        account.code_hash = Utils.keccak(code)
        update_account(address, account)
        db[account.code_hash] = code
      end

      def get_account_code(address)
        db[find_account(address).code_hash] || ''.b
      end

      def touch_account(address)
        update_account(address, find_account(address))
      end

      def find_account(address)
        rlp_encoded_account = @trie[convert_key address]
        if rlp_encoded_account.nil? || rlp_encoded_account.size == 0
          Types::Account.new_empty
        else
          Types::Account.rlp_decode(rlp_encoded_account)
        end
      end

      def account_exist?(address)
        rlp_encoded_account = @trie[convert_key address]
        non_exists = rlp_encoded_account.nil? || rlp_encoded_account.size == 0
        !non_exists
      end

      def delete_account(address)
        debug "delete #{address.to_s.to_hex}"
        @trie.delete(convert_key address)
      end

      def account_dead?(address)
        find_account(address).empty?
      end

      private

      def update_account(address, account)
        debug 'update account'
        debug address.to_hex
        debug account.serializable_attributes
        @trie[convert_key address] = Types::Account.rlp_encode account
      end

      def convert_key(key)
        Utils.keccak key.to_s
      end

    end
  end
end
