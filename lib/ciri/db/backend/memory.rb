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


require 'forwardable'
require_relative 'errors'

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

        extend Forwardable

        def initialize
          @db = {}
        end

        def initialize_copy(orig)
          super
          @db = orig.instance_variable_get(:@db).dup
        end

        def_delegators :db, :[], :[]=, :fetch, :delete, :include?

        def get(key)
          db[key]
        end

        def put(key, value)
          db[key] = value
        end

        def batch
          b = Batch.new
          yield(b)
          db.merge! b.value
        end

        def close
          @db = nil
        end

        def closed?
          @db.nil?
        end

        private
        def db
          @db || raise(InvalidError.new 'db is closed')
        end

      end
    end
  end
end
