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


require 'ciri/rlp'

module Ciri
  module POWChain

    # block header
    class Header
      include RLP::Serializable

      schema(
          parent_hash: RLP::Bytes,
          ommers_hash: RLP::Bytes,
          beneficiary: RLP::Bytes,
          state_root: RLP::Bytes,
          transactions_root: RLP::Bytes,
          receipts_root: RLP::Bytes,
          logs_bloom: RLP::Bytes,
          difficulty: Integer,
          number: Integer,
          gas_limit: Integer,
          gas_used: Integer,
          timestamp: Integer,
          extra_data: RLP::Bytes,
          mix_hash: RLP::Bytes,
          nonce: RLP::Bytes,
      )

      # header hash
      def get_hash
        Utils.keccak(rlp_encode)
      end

      # mining_hash, used for mining
      def mining_hash
        Utils.keccak(rlp_encode skip_keys: [:mix_hash, :nonce])
      end

      def inspect
        h = {}
        self.class.schema.keys.each do |key|
          key_schema = self.class.schema[key]
          h[key] = if key_schema.type == RLP::Bytes
                     Utils.to_hex serializable_attributes[key]
                   else
                     serializable_attributes[key]
                   end
        end
        h
      end
    end

  end
end
