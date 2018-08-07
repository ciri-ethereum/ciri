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


require 'ffi'

module Ciri
  module DB
    module Backend
      module RocksDB

        class Error < StandardError
        end

        module RocksDBLib
          extend FFI::Library
          ffi_lib 'rocksdb'

          attach_function :rocksdb_options_create, [], :pointer
          attach_function :rocksdb_options_set_create_if_missing, [:pointer, :int], :void
          attach_function :rocksdb_open, [:pointer, :string, :pointer], :pointer
          attach_function :rocksdb_close, [:pointer], :void
          attach_function :rocksdb_writeoptions_create, [], :pointer
          attach_function :rocksdb_readoptions_create, [], :pointer
          attach_function :rocksdb_writeoptions_destroy, [:pointer], :void
          attach_function :rocksdb_readoptions_destroy, [:pointer], :void
          attach_function :rocksdb_options_destroy, [:pointer], :void
          attach_function :rocksdb_put, [:pointer, :pointer, :pointer, :int, :pointer, :int, :pointer], :void
          attach_function :rocksdb_get, [:pointer, :pointer, :pointer, :int, :pointer, :pointer], :pointer
          attach_function :rocksdb_delete, [:pointer, :pointer, :pointer, :int, :pointer], :void
          attach_function :rocksdb_write, [:pointer, :pointer, :pointer, :pointer], :void
          # iterator
          attach_function :rocksdb_create_iterator, [:pointer, :pointer], :pointer
          attach_function :rocksdb_iter_destroy, [:pointer], :void
          attach_function :rocksdb_iter_valid, [:pointer], :uchar
          attach_function :rocksdb_iter_seek_to_first, [:pointer], :void
          attach_function :rocksdb_iter_seek_to_last, [:pointer], :void
          attach_function :rocksdb_iter_seek, [:pointer, :string, :int], :void
          attach_function :rocksdb_iter_seek_for_prev, [:pointer, :string, :int], :void
          attach_function :rocksdb_iter_next, [:pointer], :void
          attach_function :rocksdb_iter_prev, [:pointer], :void
          attach_function :rocksdb_iter_key, [:pointer, :pointer], :string
          attach_function :rocksdb_iter_value, [:pointer, :pointer], :string
          # batch
          attach_function :rocksdb_writebatch_create, [], :pointer
          attach_function :rocksdb_writebatch_destroy, [:pointer], :void
          attach_function :rocksdb_writebatch_put, [:pointer, :pointer, :int, :pointer, :int], :void
          attach_function :rocksdb_writebatch_delete, [:pointer, :string, :int], :void
          attach_function :rocksdb_writebatch_count, [:pointer], :int

          class << self
            def open_database(path, options)
              err_ptr = FFI::MemoryPointer.new :string
              db = rocksdb_open(options, path, err_ptr)
              raise_error_from_point(Error, err_ptr)
              db
            end

            def close_database(db)
              rocksdb_close(db)
              nil
            end

            def put(db, write_options, key, value)
              err_ptr = FFI::MemoryPointer.new :pointer
              # use pointer to aboid ffi null string issue
              key_ptr = FFI::MemoryPointer.from_string(key)
              value_ptr = FFI::MemoryPointer.from_string(value)
              rocksdb_put(db, write_options, key_ptr, key.size, value_ptr, value.size + 1, err_ptr)
              raise_error_from_point(Error, err_ptr)
              nil
            end

            def get(db, read_options, key)
              err_ptr = FFI::MemoryPointer.new :pointer
              value_len = FFI::MemoryPointer.new :int
              value_ptr = RocksDBLib.rocksdb_get(db, read_options, key, key.size, value_len, err_ptr)
              raise_error_from_point(Error, err_ptr)
              len = value_len.read_int - 1
              key_exists = len > 0 && !value_ptr.null?
              key_exists ? value_ptr.read_string(len) : nil
            end

            def delete(db, write_options, key)
              key_ptr = FFI::MemoryPointer.from_string(key)
              err_ptr = FFI::MemoryPointer.new :pointer
              RocksDBLib.rocksdb_delete(db, write_options, key_ptr, key.size, err_ptr)
              raise_error_from_point(Error, err_ptr)
              nil
            end

            def write(db, write_options, batch)
              err_ptr = FFI::MemoryPointer.new :pointer
              RocksDBLib.rocksdb_write(db, write_options, batch, err_ptr)
              raise_error_from_point(Error, err_ptr)
              nil
            end

            def writebatch_put(batch, key, value)
              key_ptr = FFI::MemoryPointer.from_string(key)
              value_ptr = FFI::MemoryPointer.from_string(value)
              rocksdb_writebatch_put(batch, key_ptr, key.size, value_ptr, value.size + 1)
              nil
            end

            def writebatch_delete(batch, key)
              rocksdb_writebatch_delete(batch, key, key.size)
              nil
            end

            private

            def raise_error_from_point(error_klass, err_ptr)
              err = err_ptr.get_pointer(0)
              raise error_klass.new(err.read_string_to_null) unless err.null?
            end
          end
        end

        class Batch
          def initialize
            @batch = RocksDBLib.rocksdb_writebatch_create
            ObjectSpace.define_finalizer(self, self.class.finalizer(@batch))
          end

          def put(key, value)
            RocksDBLib.writebatch_put(@batch, key, value)
          end

          def delete(key)
            RocksDBLib.writebatch_delete(@batch, key)
          end

          def raw_batch
            @batch
          end

          class << self
            def finalizer(batch)
              proc {
                RocksDBLib.rocksdb_writebatch_destroy(batch)
              }
            end
          end
        end

        class Iterator
          def initialize(db, readoptions)
            @iter = RocksDBLib.rocksdb_create_iterator(db, readoptions)
          end

          def valid
            RocksDBLib.rocksdb_iter_valid(@iter) == 1
          end

          def seek_to_first
            RocksDBLib.rocksdb_iter_seek_to_first(@iter)
            nil
          end

          def seek_to_last
            RocksDBLib.rocksdb_iter_seek_to_last(@iter)
            nil
          end

          def seek(key)
            RocksDBLib.rocksdb_iter_seek(@iter, key, key.size)
            nil
          end

          def seek_for_prev(key)
            RocksDBLib.rocksdb_iter_seek_for_prev(@iter, key, key.size)
            nil
          end

          def next
            RocksDBLib.rocksdb_iter_next(@iter)
            nil
          end

          def prev
            RocksDBLib.rocksdb_iter_prev(@iter)
            nil
          end

          def key
            len_ptr = FFI::MemoryPointer.new :int
            key = RocksDBLib.rocksdb_iter_key(@iter, len_ptr)
            len = len_ptr.read_int
            key[0...len]
          end

          def value
            len_ptr = FFI::MemoryPointer.new :int
            value = RocksDBLib.rocksdb_iter_value(@iter, len_ptr)
            len = len_ptr.read_int
            value[0...len]
          end

          def close
            RocksDBLib.rocksdb_iter_destroy(@iter)
          end
        end

        class DB
          def initialize(path)
            options = RocksDBLib.rocksdb_options_create
            RocksDBLib.rocksdb_options_set_create_if_missing(options, 1)
            @db = RocksDBLib.open_database(path, options)
            @writeoptions = RocksDBLib.rocksdb_writeoptions_create
            @readoptions = RocksDBLib.rocksdb_readoptions_create
            ObjectSpace.define_finalizer(self, self.class.finalizer(@db, options, @writeoptions, @readoptions))
          end

          def get(key)
            RocksDBLib.get(@db, @readoptions, key)
          end

          alias [] get

          def put(key, value)
            RocksDBLib.put(@db, @writeoptions, key, value)
          end

          alias []= put

          def delete(key)
            RocksDBLib.delete(@db, @writeoptions, key)
          end

          def new_iterator
            Iterator.new(@db, @readoptions)
          end

          def close
            RocksDBLib.close_database(@db) if @db
            @db = nil
          end

          def closed?
            @db.nil?
          end

          def write(batch)
            RocksDBLib.write(@db, @writeoptions, batch.raw_batch)
          end

          class << self
            def finalizer(db, options, write_options, read_options)
              proc {
                # RocksDBLib.close_database(db)
                RocksDBLib.rocksdb_options_destroy(options)
                RocksDBLib.rocksdb_writeoptions_destroy(write_options)
                RocksDBLib.rocksdb_readoptions_destroy(read_options)
              }
            end
          end
        end

      end
    end
  end
end
