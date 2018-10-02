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


require 'ciri/key'
require 'ciri/utils'

module Ciri
  module DevP2P
    module RLPX

      # present node id
      class NodeID

        class << self
          def from_raw_id(raw_id)
            NodeID.new(Ciri::Key.new(raw_public_key: "\x04".b + raw_id))
          end
        end

        attr_reader :public_key

        alias key public_key

        def initialize(public_key)
          unless public_key.is_a?(Ciri::Key)
            raise TypeError.new("expect Ciri::Key but get #{public_key.class}")
          end
          @public_key = public_key
        end

        def id
          @id ||= key.raw_public_key[1..-1]
        end

        def == (other)
          self.class == other.class && id == other.id
        end

        def to_s
          Ciri::Utils.to_hex id
        end

        alias to_str to_s

      end

      class Node
        attr_reader :node_id, :ip, :udp_port, :tcp_port, :added_at

        def initialize(node_id:, ip:, udp_port:, tcp_port:, added_at: nil)
          @node_id = node_id
          @ip = ip
          @udp_port = udp_port
          @tcp_port = tcp_port
          @added_at = added_at
        end

        def == (other)
          self.class == other.class && node_id == other.node_id
        end
      end

    end
  end
end
