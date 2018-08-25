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


require 'ciri/utils'
require 'ciri/trie'
require 'ciri/rlp'

module Ciri
  module Types

    class Account
      include RLP::Serializable

      schema(
          nonce: Integer,
          balance: Integer,
          storage_root: RLP::Bytes,
          code_hash: RLP::Bytes
      )

      default_data code_hash: Utils::BLANK_SHA3, storage_root: Trie::BLANK_NODE_HASH

      # EMPTY(σ,a) ≡ σ[a]c =KEC􏰁()􏰂∧σ[a]n =0∧σ[a]b =0
      def empty?
        !has_code? && nonce == 0 && balance == 0
      end

      def has_code?
        code_hash != Utils::BLANK_SHA3
      end

      class << self
        def new_empty
          Account.new(balance: 0, nonce: 0)
        end
      end

    end

  end
end
