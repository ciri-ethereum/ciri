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
require 'ciri/rlp'

module Ciri
  module Types
    class Address

      class << self
        def rlp_encode(address)
          RLP.encode(address.to_s)
        end

        def rlp_decode(data)
          address = self.new(RLP.decode(data))
          address.validate
          address
        end
      end

      include Errors

      def initialize(address)
        @address = address.to_s
      end

      def ==(other)
        self.class == other.class && to_s == other.to_s
      end

      def to_s
        @address
      end

      alias to_str to_s

      def to_hex
        Utils.to_hex to_s
      end

      def empty?
        @address.empty?
      end

      def validate
        # empty address is valid
        return if empty?
        raise InvalidError.new("address must be 20 size, got #{@address.size}") unless @address.size == 20
      end

    end
  end
end
