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


require 'ciri/key'

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
