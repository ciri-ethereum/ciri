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
require 'ciri/crypto'
require 'ciri/key'
require 'ciri/types/address'
require 'ciri/types/uint'

module Ciri
  module POWChain
    class Transaction

      include Types

      class InvalidError < StandardError
      end

      EIP155_CHAIN_ID_OFFSET = 35
      V_OFFSET = 27

      include RLP::Serializable

      schema [
                 {nonce: Integer},
                 {gas_price: Integer},
                 {gas_limit: Integer},
                 {to: Address},
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
          address = Key.ecdsa_recover(sign_hash(chain_id), signature).to_address
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
        Utils.keccak(RLP.encode_simple list)
      end

      def get_hash
        Utils.keccak rlp_encode
      end

      # validate transaction
      def validate!
        raise NotImplementedError
      end

      def validate_sender!
        begin
          sender
        rescue Ciri::Crypto::ECDSASignatureError => e
          raise InvalidError.new("recover signature error, error: #{e}")
        rescue Ciri::Types::Errors::InvalidError => e
          raise InvalidError.new(e.to_s)
        end
      end

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
