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

module Ciri
  module DB
    class AccountDB

      include Serialize

      attr_reader :state

      def initialize(state, root_hash: nil)
        @state = state
        root_hash ||= Trie::BLANK_NODE_HASH
        @trie = Trie.new(db: @state, root_hash: root_hash, prune: true)
      end

      def root_hash
        @trie.root_hash
      end

      def store(address, key, data)
        data_is_blank = Ciri::Utils.blank_bytes?(data)
        # key_is_blank = Ciri::Utils.blank_binary?(key)

        return unless data && !data_is_blank

        # remove unnecessary null byte from key
        key = serialize(key).gsub(/\A\0+/, ''.b)
        key = "\x00".b if key.empty?

        account = find_account address
        trie = Trie.new(db: @state, root_hash: account.storage_root)
        trie[key] = serialize(data).rjust(32, "\x00".b)
        account.storage_root = trie.root_hash
        update_account(address, account)
      end

      def fetch(address, key)
        # remove unnecessary null byte from key
        key = serialize(key).gsub(/\A\0+/, ''.b)
        key = "\x00".b if key.empty?
        account = find_account address
        trie = Trie.new(db: @state, root_hash: account.storage_root)
        trie[key] || ''.b
      end

      def set_account_code(address, code)
        code ||= ''.b
        account = find_account(address)
        account.code_hash = Utils.sha3(code)
        update_account(address, account)
        state[account.code_hash] = code
      end

      def get_account_code(address)
        state[find_account(address).code_hash] || ''.b
      end

      def find_account(address)
        rlp_encoded_account = @trie[convert_key address]
        if rlp_encoded_account.nil? || rlp_encoded_account.size == 0
          Types::Account.new_empty
        else
          Types::Account.rlp_decode(rlp_encoded_account)
        end
      end

      def account_dead?(address)
        find_account(address).empty?
      end

      def update_account(address, account)
        @trie[convert_key address] = Types::Account.rlp_encode account
      end

      private

      def convert_key(key)
        Utils.sha3 key.to_s
      end

    end
  end
end
