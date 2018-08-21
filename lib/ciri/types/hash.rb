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


require_relative 'errors'

module Ciri
  module Types

    class Hash32

      class << self
        def rlp_encode(hash32)
          RLP.encode(hash32.to_s)
        end

        def rlp_decode(data)
          hash32 = self.new(RLP.decode(data))
          hash32.validate
          hash32
        end
      end

      include Errors

      def initialize(h)
        @hash32 = h.to_s
      end

      def ==(other)
        self.class == other.class && to_s == other.to_s
      end

      def to_s
        @hash32
      end

      alias to_str to_s

      def to_hex
        Utils.to_hex to_s
      end

      def empty?
        @hash32.empty?
      end

      def validate
        # empty address is valid
        return if empty?
        raise InvalidError.new("hash32 must be 32 size, got #{@hash32.size}") unless @hash32.size == 32
      end

    end
  end
end
