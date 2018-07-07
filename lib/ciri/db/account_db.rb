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


require 'ciri/trie'
require 'ciri/types/account'
require 'ciri/serialize'
require 'ciri/utils/logger'

module Ciri
  module DB
    class AccountDB

      include Serialize
      include Utils::Logger

      attr_reader :db

      def initialize(db, root_hash: nil)
        @db = db
        root_hash ||= Trie::BLANK_NODE_HASH
        @trie = Trie.new(db: @db, root_hash: root_hash, prune: true)
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
        account.code_hash = Utils.sha3(code)
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

      def delete_account(address)
        @trie.delete(convert_key address)
      end

      def account_dead?(address)
        find_account(address).empty?
      end

      private

      def update_account(address, account)
        debug 'update account'
        debug Utils.to_hex(address)
        debug account.serializable_attributes
        @trie[convert_key address] = Types::Account.rlp_encode account
      end

      def convert_key(key)
        Utils.sha3 key.to_s
      end

    end
  end
end
