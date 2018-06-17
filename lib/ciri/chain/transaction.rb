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


require 'ciri/rlp'
require 'ciri/crypto'

module Ciri
  class Chain

    class Transaction
      include RLP::Serializable

      schema [
               {nonce: Integer},
               {gas_price: Integer},
               {gas_limit: Integer},
               :to,
               {value: Integer},
               :v,
               :r,
               :s,
               {init: RLP::Raw, optional: true},
               {data: RLP::Raw, optional: true}
             ]

      default_data v: 0, r: 0, s: 0, init: "\x00".b, data: "\x00".b

      # sender address
      # @return address String
      def sender
        @sender ||= begin
          signature = Crypto::Signature.new(vrs: [v, r, s])
          Utils.sha3(Crypto.ecdsa_recover(get_hash, signature))[96..255]
        end
      end

      # @param key Key
      def sign_with_key!(key)
        signature = key.ecdsa_signature(get_hash)
        self.v = signature.v
        self.r = signature.r
        self.s = signature.s
        nil
      end

      def contract_creation?
        to.nil? || to == "\x00".b
      end

      def get_hash(chain_id: nil)
        param = contract_creation? ? init : data
        s = if true #[27, 28].include? v
              [nonce, gas_price, gas_limit, to, value, param]
            else
              [nonce, gas_price, gas_limit, to, value, param, chain_id, [], []]
            end
        Utils.sha3(RLP.encode_simple s)
      end

    end

  end
end
