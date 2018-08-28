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
require 'ciri/db/backend/memory'
require 'ciri/db/backend/rocks'

RSpec.describe Ciri::DB::Backend do

  let(:tmp_dir) {Dir.mktmpdir}
  let(:rocks_db) {Ciri::DB::Backend::Rocks.new(tmp_dir)}
  let(:memory_db) {Ciri::DB::Backend::Memory.new}
  let(:stores) {[memory_db, rocks_db]}

  after do
    rocks_db.close
    FileUtils.remove_entry tmp_dir
  end

  it 'basic store' do
    stores.each do |store|
      store.put "one", "1"
      store["two"] = "2"

      expect(store["one"]).to eq "1"
      expect(store.get("two")).to eq "2"
      expect(store.get("three")).to be_nil
      expect(store.fetch("two")).to eq "2"
      expect {store.fetch("three")}.to raise_error(KeyError)
    end
  end

  it 'delete & include?' do
    stores.each do |store|
      store.put "one", "1"
      store["two"] = "2"

      expect(store.include?("one")).to be_truthy
      expect(store.include?("two")).to be_truthy

      store.delete("two")

      expect(store.include?("one")).to be_truthy
      expect(store.include?("two")).to be_falsey

      expect(store.get("two")).to be_nil
      expect {store.fetch("two")}.to raise_error(KeyError)
    end
  end

  it 'batch' do
    stores.each do |store|
      store.batch do |b|
        b.put "a", "1"
        b.put "b", "2"
      end
      expect(["a", "b"].map {|k| store[k]}).to eq ["1", "2"]

      expect do
        store.batch do |b|
          b.put "c", "1"
          raise StandardError.new("winter is coming")
          b.put "d", "2"
        end
      end.to raise_error(StandardError, 'winter is coming')
      expect(["a", "b", "c", "d"].map {|k| store[k]}).to eq ["1", "2", nil, nil]
    end
  end

  it 'closed' do
    stores.each do |store|
      expect(store.closed?).to be_falsey
      expect(store.close).to be_nil
      expect(store.closed?).to be_truthy
      expect do
        store["eh?"]
      end.to raise_error(Ciri::DB::Backend::InvalidError)
    end
  end

  it 'handle null byte string' do
    stores.each do |store|
      store.put "onetwo", "1\u00002"
      expect(store["onetwo"]).to eq "1\u00002"

      store.put "1\u00002", "onetwo"
      expect(store["1\u00002"]).to eq "onetwo"
    end
  end

end
