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


require 'ciri/utils'
module Ciri

  # modified from py-evm
  class BloomFilter

    def initialize(value = 0)
      @value = value
    end

    def <<(value)
      get_bloom_bits(value).each do |v|
        @value |= v
      end
    end

    def extend(list)
      list.each do |value|
        self << value
      end
    end

    def |(value)
      BloomFilter.new(@value | value.to_i)
    end

    def include?(value)
      get_bloom_bits(value).all? do |bits|
        @value & bits != 0
      end
    end

    def to_i
      @value
    end

    def self.from_iterable(list)
      b = BloomFilter.new
      b.extend(list)
      b
    end

    private

    def get_bloom_bits(value)
      value_hash = Utils.keccak(value)
      get_chunks_for_bloom(value_hash).map {|v| chunk_to_bloom_bits(v)}
    end

    def get_chunks_for_bloom(value)
      value[0..5].each_char.each_slice(2).map(&:join)
    end

    def chunk_to_bloom_bits(value)
      high, low = value.each_byte.to_a
      1 << ((low + (high << 8)) & 2047)
    end

  end
end
