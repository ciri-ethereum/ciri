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
require 'ciri/types/address'

module Ciri
  class Chain

    class Transaction
      EIP155_CHAIN_ID_OFFSET = 35
      V_OFFSET = 27

      include RLP::Serializable

      schema [
               {nonce: Integer},
               {gas_price: Integer},
               {gas_limit: Integer},
               {to: Types::Address},
               {value: Integer},
               :data,
               {v: Integer},
               {r: Integer},
               {s: Integer}
             ]

      default_data v: 0, r: 0, s: 0, data: "\x00".b

      # sender address
      # @return address String
      def sender
        @sender ||= begin
          Utils.sha3(Crypto.ecdsa_recover(sign_hash(chain_id), signature)[1..-1])[-20..-1]
        end
      end

      def signature
        v = if eip_155_signed_transaction?
              (self.v - 1) % 2
            elsif [27, 28].include?(self.v)
              self.v - 27
            else
              self.v
            end
        Crypto::Signature.new(vrs: [v, r, s])
      end

      # @param key Key
      def sign_with_key!(key)
        signature = key.ecdsa_signature(sign_hash)
        self.v = signature.v
        self.r = signature.r
        self.s = signature.s
        nil
      end

      def contract_creation?
        to.nil? || to == "\x00".b
      end

      def sign_hash(chain_id = nil)
        param = data || ''.b
        list = [nonce, gas_price, gas_limit, to, value, param]
        if chain_id
          list += [chain_id, ''.b, ''.b]
        end
        Utils.sha3(RLP.encode_simple list)
      end

      def get_hash
        Utils.sha3 rlp_encode!
      end

      private

      # return chain_id by v
      def chain_id
        if eip_155_signed_transaction?
          (v - 35) / 2
        end
      end

      def eip_155_signed_transaction?
        v >= EIP155_CHAIN_ID_OFFSET
      end

    end

  end
end
