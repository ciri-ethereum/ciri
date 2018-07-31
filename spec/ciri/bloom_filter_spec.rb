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
      expect(bloom_filter.include? Ciri::Types::Int32.new(topic).to_bytes).to be_truthy
    end
  end

  it 'other values' do
    bloom_filter = Ciri::BloomFilter.new
    bloom_filter << "harry potter"
    expect(bloom_filter.include?("harry potter")).to be_truthy
    expect(bloom_filter.include?("voldemort")).to be_falsey
  end

end
