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


require 'ciri/pow_chain/chain'
require 'forwardable'
require_relative 'protocol_messages'

module Ciri
  module Eth

    # eth protocol peer
    class Peer
      attr_reader :io, :total_difficulty, :status

      extend Forwardable

      def_delegators :@peer, :to_s

      def initialize(protocol_manage:, peer:, io:)
        @protocol_manage = protocol_manage
        @io = io
        @total_difficulty = nil
        @peer = peer
      end

      # do eth protocol handshake and return status
      def handshake(network_id, total_difficulty, head_hash, genesis_hash)
        status = Status.new(protocol_version: 63, network_id: network_id,
                            total_difficulty: total_difficulty, current_block: head_hash, genesis_block: genesis_hash)
        io.send_data(Status::CODE, status.rlp_encode)
        msg = io.read_msg
        @status = Status.rlp_decode(msg.payload)
        @total_difficulty = @status.total_difficulty
        @status
      end

      def send_msg(msg_class, **data)
        msg = msg_class.new(data)
        io.send_data(msg_class::CODE, msg.rlp_encode)
      end
    end

  end
end