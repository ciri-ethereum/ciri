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


require 'ciri/types/address'
require 'ciri/core_ext'

using Ciri::CoreExt

module Ciri
  module Serialize

    extend self

    def serialize(item)
      case item
      when Integer
        Utils.big_endian_encode(item)
      when Types::Address
        item.to_s
      else
        item
      end
    end

    def deserialize(type, item)
      if type == Integer && !item.is_a?(Integer)
        Utils.big_endian_decode(item.to_s)
      elsif type == Types::Address && !item.is_a?(Types::Address)
        # check if address represent in Integer
        item = Utils.big_endian_encode(item) if item.is_a?(Integer)
        Types::Address.new(item.size >= 20 ? item[-20..-1] : item.pad_zero(20))
      elsif type.nil?
        # get serialized word
        serialize(item).rjust(32, "\x00".b)
      else
        item
      end
    end

  end
end
