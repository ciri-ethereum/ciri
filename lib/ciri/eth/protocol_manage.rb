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


require 'ciri/actor'
require 'ciri/chain'
require_relative 'peer'
require_relative 'synchronizer'

module Ciri
  module Eth

    # ProtocolManage
    class ProtocolManage

      MAX_RESPONSE_HEADERS = 10

      include Ciri::Actor

      attr_reader :protocols, :synchronizer, :chain

      def initialize(protocols:, chain:)
        @protocols = protocols
        @peers = {}
        @chain = chain

        @synchronizer = Synchronizer.new(chain: chain)
        super()
      end

      def protocols
        @protocols.each {|p| p.start = proc {|peer, io| self << [:new_peer, peer, io]}}
        @protocols
      end

      def start
        # start syncing
        synchronizer.start
        super
      end

      # new peer come in
      def new_peer(peer, io)
        peer = Peer.new(protocol_manage: self, peer: peer, io: io)
        peer.handshake(1, chain.total_difficulty, chain.head.get_hash, chain.genesis_hash)
        @peers[peer] = true

        # register peer to synchronizer
        synchronizer << [:register_peer, peer]
        # start handle peer messages
        executor.post {handle_peer(peer)}
      end

      def handle_peer(peer)
        handle_msg(peer, peer.io.read_msg) while true
      end

      def handle_msg(peer, msg)
        case msg.code
        when GetBlockHeaders::CODE
          get_header_msg = GetBlockHeaders.rlp_decode(msg.payload)
          hash_or_number = get_header_msg.hash_or_number

          header = if hash_or_number.is_a?(Integer)
                     chain.get_header_by_number hash_or_number
                   else
                     chain.get_header hash_or_number
                   end
          headers = []

          if header
            amount = [MAX_RESPONSE_HEADERS, get_header_msg.amount].min
            # skip
            get_header_msg.skip.times do
              next_header = chain.get_header_by_number header.number + 1
              break if next_header.nil? || next_header.parent_hash != header.get_hash
              header = next_header
            end
            amount.times do
              headers << header
              next_header = chain.get_header_by_number header.number + 1
              break if next_header.nil? || next_header.parent_hash != header.get_hash
              header = next_header
            end
            header.reverse! if get_header_msg.reverse
          end

          headers_msg = BlockHeaders.new(headers: headers).rlp_encode
          peer.io.send_data(BlockHeaders::CODE, headers_msg)
        when BlockHeaders::CODE
          headers = BlockHeaders.rlp_decode(msg.payload).headers
          synchronizer << [:receive_headers, peer, headers] unless headers.empty?
        when BlockBodies::CODE
          bodies = BlockBodies.rlp_decode(msg.payload).bodies
          synchronizer << [:receive_bodies, peer, bodies] unless bodies.empty?
        else
          raise StandardError, "unknown code #{msg.code}, #{msg}"
        end
      end
    end

  end
end
