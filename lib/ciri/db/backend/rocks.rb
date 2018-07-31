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


require_relative 'rocks_db'
require 'forwardable'

module Ciri
  module DB
    module Backend

      # implement kvstore
      class Rocks

        class InvalidError < StandardError
        end

        extend Forwardable

        def initialize(path)
          @db = RocksDB::DB.new(path)
        end

        def_delegators :db, :get, :put, :[], :[]=

        def each(&blk)
          inter_each(only_key: false, &blk)
        end

        def keys(key: nil)
          inter_each(key: key, only_key: true)
        end

        def scan(key, &blk)
          inter_each(key: key, only_key: false, &blk)
        end

        def batch
          batch = RocksDB::Batch.new
          yield batch
          db.write(batch)
          self
        end

        def close
          return if closed?
          db.close
          @db = nil
        end

        def closed?
          @db.nil?
        end

        private

        def db
          @db || raise(InvalidError.new 'db is not open')
        end

        def inter_each(key: nil, only_key: true, &blk)
          i = db.new_iterator
          key ? i.seek(key) : i.seek_to_first

          enum = Enumerator.new do |iter|
            while i.valid
              iter << (only_key ? i.key : [i.key, i.value])
              i.next
            end
          ensure
            i.close
          end

          if blk.nil?
            enum
          else
            enum.each(&blk)
            self
          end
        end

      end
    end
  end
end
