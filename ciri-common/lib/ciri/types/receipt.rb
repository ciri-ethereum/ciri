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


require 'ciri/rlp'
require 'ciri/bloom_filter'
require 'ciri/types/uint'
require 'ciri/types/log_entry'

module Ciri
  module Types

    class Receipt

      include RLP::Serializable

      schema(
          state_root: RLP::Bytes,
          gas_used: Integer,
          bloom: Types::UInt256,
          logs: [LogEntry],
      )

      def initialize(state_root:, gas_used:, logs:, bloom: nil)
        bloom ||= begin
          blooms = logs.reduce([]) {|list, log| list.append *log.to_blooms}
          BloomFilter.from_iterable(blooms).to_i
        end
        super(state_root: state_root, gas_used: gas_used, logs: logs, bloom: bloom)
      end

      def bloom_filter
        BloomFilter.new(bloom)
      end

    end

  end
end
