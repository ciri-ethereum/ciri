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


require 'ciri/chain'
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