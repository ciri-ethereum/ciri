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
        @address.empty? || @address.each_byte.reduce(0, :+).zero?
      end

      def validate
        # empty address is valid
        return if empty?
        raise InvalidError.new("address must be 20 size, got #{@address.size}") unless @address.size == 20
      end

    end
  end
end
