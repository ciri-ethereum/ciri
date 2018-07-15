# frozen_string_literal: true

# Copyright (c) 2018, by Jiang Jinyang. <https://justjjy.com>, classicalliu.
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

require "ciri/utils"
require_relative "./errors"

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
