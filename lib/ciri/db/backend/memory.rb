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


require_relative 'rocks_db'
require 'forwardable'

module Ciri
  module DB
    module Backend

      # implement kvstore
      class Memory

        class Batch
          attr_reader :value

          def initialize
            @value = Hash.new
          end

          def put(k, v)
            @value[k] = v
          end
        end

        class InvalidError < StandardError
        end

        extend Forwardable

        def initialize
          @db = {}
        end

        def initialize_copy(orig)
          super
          @db = orig.instance_variable_get(:@db).dup
        end

        def_delegators :@db, :[], :[]=, :fetch, :delete, :include?

        def get(key)
          @db[key]
        end

        def put(key, value)
          @db[key] = value
        end

        def each(&blk)
          keys.each(&blk)
        end

        def batch
          b = Batch.new
          yield(b)
          @db.merge! b.value
        end

        def close
          @db = nil
        end

        def closed?
          @db.nil?
        end

      end
    end
  end
end
