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
