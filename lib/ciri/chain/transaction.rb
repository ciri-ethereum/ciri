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

      class InvalidError < StandardError
      end

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
          address = Types::Address.new(Utils.sha3(Crypto.ecdsa_recover(sign_hash(chain_id), signature)[1..-1])[-20..-1])
          address.validate
          address
        end
      end

      def signature
        v = if eip_155_signed_transaction?
              # retrieve actually v from transaction.v, see EIP-155(prevent replay attack)
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
        to.empty?
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
        Utils.sha3 rlp_encode
      end

      # validate transaction
      # @param intrinsic_gas_of_transaction Proc
      def validate!(intrinsic_gas_of_transaction: nil)
        begin
          sender
        rescue Ciri::Crypto::ECDSASignatureError => e
          raise InvalidError.new("recover signature error, error: #{e}")
        rescue Ciri::Types::Errors::InvalidError => e
          raise InvalidError.new(e.to_s)
        end

        raise InvalidError.new('signature rvs error') unless signature.valid?
        raise InvalidError.new('signature s is low') unless signature.low_s?

        if intrinsic_gas_of_transaction
          begin
            intrinsic_gas = intrinsic_gas_of_transaction[self]
          rescue StandardError
            raise InvalidError.new 'intrinsic gas calculation error'
          end
          raise InvalidError.new 'intrinsic gas not enough' unless intrinsic_gas <= gas_limit
        end
      end

      private

      # return chain_id by v
      def chain_id
        if eip_155_signed_transaction?
          # retrieve chain_id from v, see EIP-155
          (v - 35) / 2
        end
      end

      # https://github.com/ethereum/EIPs/blob/984cf5de90bbf5fbe7e49be227b0c2f9567e661e/EIPS/eip-155.md
      def eip_155_signed_transaction?
        v >= EIP155_CHAIN_ID_OFFSET
      end

    end

  end
end
