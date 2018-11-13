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


require 'ciri/pow_chain/chain'
require 'forwardable'
require_relative 'protocol_messages'

module Ciri
  module Eth

    # eth protocol peer
    class PeerContext
      attr_reader :total_difficulty, :status, :peer

      extend Forwardable

      def_delegators :@peer, :to_s, :hash

      def initialize(peer:, context:)
        @total_difficulty = nil
        @peer = peer
        @context = context
      end

      # do eth protocol handshake and return status
      def send_handshake(network_id, total_difficulty, head_hash, genesis_hash)
        status = Status.new(protocol_version: 63, network_id: network_id,
                            total_difficulty: total_difficulty, current_block: head_hash, genesis_block: genesis_hash)
        @context.send_data(Status::CODE, status.rlp_encode)
      end

      def set_status(status)
        @status ||= status
        @total_difficulty = @status.total_difficulty
      end

      def send_msg(msg_class, **data)
        msg = msg_class.new(data)
        @context.send_data(msg_class::CODE, msg.rlp_encode)
      end

      def ==(peer_context)
        self.class == peer_context.class && peer == peer_context.peer
      end

      alias eql? ==
    end

  end
end
