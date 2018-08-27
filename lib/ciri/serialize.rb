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
