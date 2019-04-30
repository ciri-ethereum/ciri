# frozen_string_literal: true

# Copyright (c) 2018 by Jiang Jinyang <jjyruby@gmail.com>
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
