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
require 'ciri/trie'
require 'ciri/utils'

RSpec.describe Ciri::Trie do

  before(:all) do
    prepare_ethereum_fixtures
  end

  run_test_case = proc do |test_case, prefix: nil, tags: {}|
    test_case.each do |name, t|

      it "#{prefix} #{name}", **tags do
        # in
        input = t['in'].map do |key, value|
          [
            key.start_with?('0x') ? Ciri::Utils.to_bytes(key) : key,
            value&.start_with?('0x') ? Ciri::Utils.to_bytes(value) : value
          ]
        end

        trie = Ciri::Trie.new
        input.each do |k, v|
          if v
            trie[k] = v
          else
            trie.delete(k)
          end

        end
        expect(Ciri::Utils.to_hex trie.root_hash).to eq (t['root'])

      end

    end
  end

  slow_tests = %w{}.map {|f| [f, true]}.to_h

  Dir.glob("fixtures/TrieTests/trietest.json").each do |topic|
    tags = {}

    # add slow_tests tag
    if slow_tests.include? topic
      tags = {slow_tests: true}
    end

    run_test_case[JSON.load(open topic), prefix: 'fixtures/TrieTests', tags: tags]
  end

end
