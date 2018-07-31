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

module Ciri
  # Core extension module for convenient
  module CoreExt

    refine(String) do
      def to_hex
        Utils.to_hex(self)
      end

      alias encode_hex to_hex

      def decode_hex
        Utils.to_bytes(self)
      end

      def keccak
        Utils.keccak(self)
      end

      def decode_big_endian
        Utils.big_endian_decode(self)
      end

      alias decode_number decode_big_endian

      def pad_zero(size)
        self.rjust(size, "\x00".b)
      end
    end

    refine(Integer) do
      def ceil_div(size)
        Utils.ceil_div(self, size)
      end

      def encode_big_endian
        Utils.big_endian_encode(self)
      end
    end

  end
end