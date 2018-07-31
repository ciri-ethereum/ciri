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
require 'fileutils'
require 'ciri/db/backend/rocks'

RSpec.describe Ciri::DB::Backend::Rocks do

  let(:tmp_dir) {Dir.mktmpdir}
  let(:store) {Ciri::DB::Backend::Rocks.new(tmp_dir)}

  after do
    store.close
    FileUtils.remove_entry tmp_dir
  end

  it 'basic store' do
    store.put "one", "1"
    store["two"] = "2"

    expect(store["one"]).to eq "1"
    expect(store.get("two")).to eq "2"
    expect(store.get("three")).to be_nil

    expect(store.keys.to_a).to eq ["one", "two"]
    values = []
    store.keys.each {|i| values << i}
    expect(values).to eq ["one", "two"]

    expect(store.each.to_a).to eq [["one", "1"], ["two", "2"]]
  end

  it 'scan' do
    store["apple"] = "1"
    store["banana"] = "2"
    store["pineapple"] = "3"
    store["pen"] = "4"
    expect(store.scan("p").to_a).to eq [["pen", "4"], ["pineapple", "3"]]
    expect(store.scan("pe").to_a).to eq [["pen", "4"], ["pineapple", "3"]]
    expect(store.scan("pi").to_a).to eq [["pineapple", "3"]]
  end

  it 'batch' do
    store.batch do |b|
      b.put "a", "1"
      b.put "b", "2"
    end
    expect(store.keys.to_a).to eq ["a", "b"]

    expect do
      store.batch do |b|
        b.put "c", "1"
        raise StandardError.new("winter is coming")
        b.put "d", "2"
      end
    end.to raise_error(StandardError, 'winter is coming')
    expect(store.keys.to_a).to eq ["a", "b"]
  end

  it 'closed' do
    expect(store.closed?).to be_falsey
    expect(store.close).to be_nil
    expect(store.closed?).to be_truthy
    expect do
      store["eh?"]
    end.to raise_error(Ciri::DB::Backend::Rocks::InvalidError)
  end

  it 'handle null byte string' do
    store.put "onetwo", "1\u00002"
    expect(store["onetwo"]).to eq "1\u00002"

    store.put "1\u00002", "onetwo"
    expect(store["1\u00002"]).to eq "onetwo"
  end

end
