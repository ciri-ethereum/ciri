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


require 'spec_helper'
require 'ciri/bloom_filter'
require 'ciri/evm/log_entry'
require 'ciri/types/number'
require 'ciri/utils'


RSpec.describe Ciri::BloomFilter do
  it 'with log entry' do
    address = "\x00".b * 20
    topics = 5.times.map {rand(100)}
    log_entry = Ciri::EVM::LogEntry.new(address: address, topics: topics, data: ''.b)

    bloom_filter = Ciri::BloomFilter.from_iterable(log_entry.to_blooms)
    topics.each do |topic|
      expect(bloom_filter.include? Ciri::Types::U256.new(topic).to_bytes).to be_truthy
    end
  end

  it 'other values' do
    bloom_filter = Ciri::BloomFilter.new
    bloom_filter << "harry potter"
    expect(bloom_filter.include?("harry potter")).to be_truthy
    expect(bloom_filter.include?("voldemort")).to be_falsey
  end

end
