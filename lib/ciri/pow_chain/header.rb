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


require 'ciri/rlp'

module Ciri
  module POWChain

    # block header
    class Header
      include RLP::Serializable

      schema [
                 {parent_hash: RLP::RawString},
                 {ommers_hash: RLP::RawString},
                 {beneficiary: RLP::RawString},
                 {state_root: RLP::RawString},
                 {transactions_root: RLP::RawString},
                 {receipts_root: RLP::RawString},
                 {logs_bloom: RLP::RawString},
                 {difficulty: Integer},
                 {number: Integer},
                 {gas_limit: Integer},
                 {gas_used: Integer},
                 {timestamp: Integer},
                 {extra_data: RLP::RawString},
                 {mix_hash: RLP::RawString},
                 {nonce: RLP::RawString},
             ]

      # header hash
      def get_hash
        Utils.keccak(rlp_encode)
      end

      # mining_hash, used for mining
      def mining_hash
        Utils.keccak(rlp_encode skip_keys: [:mix_hash, :nonce])
      end
    end

  end
end
