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
    end.to raise_error(Ciri::DB::Backend::InvalidError)
  end

  it 'handle null byte string' do
    store.put "onetwo", "1\u00002"
    expect(store["onetwo"]).to eq "1\u00002"

    store.put "1\u00002", "onetwo"
    expect(store["1\u00002"]).to eq "onetwo"
  end

end
