# frozen_string_literal: true

# Copyright 2018 Jiang Jinyang <https://justjjy.com>, classicalliu
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


require "ciri/utils"
require_relative "errors"

module Ciri
  module Crypto

    SECP256K1N = 115792089237316195423570985008687907852837564279074904382605163141518161494337

    class Signature
      attr_reader :r, :s, :v

      def initialize(signature: nil, vrs: nil)
        if !!signature == !!vrs
          raise ArgumentError.new("should pass signature_bytes or vrs, but can't provide both together")
        end

        if signature
          unless signature.size == 65
            raise ECDSASignatureError.new("signature size should be 65, got: #{signature.size}")
          end

          @r = Utils.big_endian_decode(signature[0...32])
          @s = Utils.big_endian_decode(signature[32...64])
          @v = Utils.big_endian_decode(signature[64])
        else
          @v, @r, @s = vrs

          unless self.signature.size == 65
            raise ECDSASignatureError.new("vrs is incorrect")
          end
        end
      end

      def signature
        @signature ||= Utils.big_endian_encode(@r, "\x00".b, size: 32) +
          Utils.big_endian_encode(@s, "\x00".b, size: 32) +
          Utils.big_endian_encode(@v, "\x00".b)
      end

      alias to_s signature

      def valid?
        v <= 1 &&
          r < SECP256K1N && r >= 1 &&
          s < SECP256K1N && s >= 1
      end

      def low_s?
        s < (SECP256K1N / 2)
      end
    end

  end
end
