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
