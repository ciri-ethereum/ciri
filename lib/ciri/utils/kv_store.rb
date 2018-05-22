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


require 'rocksdb'
require 'forwardable'

module Ciri
  module Utils

    # implement kvstore
    class KVStore

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
