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


require 'ciri/core_ext'
require 'ciri/p2p/protocol'
require_relative 'peer_context'
require_relative 'synchronizer'

using Ciri::CoreExt

module Ciri
  module Eth

    class EthProtocol < P2P::Protocol
      MAX_RESPONSE_HEADERS = 10

      def initialize(name:, version:, length:, chain:)
        super(name: name, version: version, length: length)
        @chain = chain
      end

      def initialized(context)
        @synchronizer = Synchronizer.new(chain: @chain)
      end

      def connected(context, task: Async::Task.current)
        peer_context = PeerContext.new(peer: context.peer, context: context)
        peer_context.send_handshake(1, @chain.total_difficulty, @chain.head.get_hash, @chain.genesis_hash)
      end

      def disconnected(context, task: Async::Task.current)
        peer_context = PeerContext.new(peer: context.peer, context: context)
        @synchronizer.deregister_peer(peer_context)
      end

      def received(context, msg, task: Async::Task.current)
        peer_context = PeerContext.new(peer: context.peer, context: context)
        case msg.code
        when Status::CODE
          status = Status.rlp_decode(msg.payload)
          peer_context.set_status(status)
          @synchronizer.register_peer(peer_context)
        when GetBlockHeaders::CODE
          get_header_msg = GetBlockHeaders.rlp_decode(msg.payload)
          hash_or_number = get_header_msg.hash_or_number

          header = if hash_or_number.is_a?(Integer)
                     @chain.get_header_by_number hash_or_number
                   else
                     @chain.get_header hash_or_number
                   end
          headers = []

          if header
            amount = [MAX_RESPONSE_HEADERS, get_header_msg.amount].min
            # skip
            get_header_msg.skip.times do
              next_header = @chain.get_header_by_number header.number + 1
              break if next_header.nil? || next_header.parent_hash != header.get_hash
              header = next_header
            end
            amount.times do
              headers << header
              next_header = @chain.get_header_by_number header.number + 1
              break if next_header.nil? || next_header.parent_hash != header.get_hash
              header = next_header
            end
            header.reverse! if get_header_msg.reverse
          end

          headers_msg = BlockHeaders.new(headers: headers).rlp_encode
          context.send_data(BlockHeaders::CODE, headers_msg)
        when BlockHeaders::CODE
          headers = BlockHeaders.rlp_decode(msg.payload).headers
          unless headers.empty?
            task.async {@synchronizer.receive_headers(peer_context, headers)}
          end
        when BlockBodies::CODE
          bodies = BlockBodies.rlp_decode(msg.payload).bodies
          unless bodies.empty?
            task.async {@synchronizer.receive_bodies(peer_context, bodies)}
          end
        else
          raise StandardError, "unknown code #{msg.code}, #{msg}"
        end
      end
    end

  end
end

