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
            key.start_with?('0x') ? Ciri::Utils.dehex(key) : key,
            value&.start_with?('0x') ? Ciri::Utils.dehex(value) : value
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
        expect(Ciri::Utils.hex trie.root_hash).to eq (t['root'])

      end

    end
  end

  Dir.glob("fixtures/TrieTests/trietest.json").each do |topic|
    run_test_case[JSON.load(open topic), prefix: 'fixtures/TrieTests']
  end

end
