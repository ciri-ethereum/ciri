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


require 'lru_redux'
require 'ciri/utils/logger'

module Ciri
  module Eth

    # Synchronizer sync blocks with peers
    class Synchronizer
      include Ciri::Actor
      include Ciri::Utils::Logger

      HEADER_FETCH_COUNT = 10

      class PeerEntry
        attr_reader :header_queue, :body_queue, :peer
        attr_accessor :syncing

        def initialize(peer)
          @peer = peer
          @header_queue = Queue.new
          @body_queue = Queue.new
          @lru_cache = LruRedux::Cache.new(HEADER_FETCH_COUNT * 2)
        end

        def receive_header
          header_queue.pop
        end

        def receive_header_in(timeout)
          wait_seconds = 0
          while header_queue.empty?
            sleep(0.1)
            wait_seconds += 0.1
            raise Timeout::Error.new("can't receive body in #{timeout}") if wait_seconds > timeout
          end
          header_queue.pop(true)
        end

        def receive_body
          body_queue.pop
        end

        def receive_body_in(timeout)
          wait_seconds = 0
          while body_queue.empty?
            sleep(0.1)
            wait_seconds += 0.1
            raise Timeout::Error.new("can't receive body in #{timeout}") if wait_seconds > timeout
          end
          body_queue.pop(true)
        end

        def fetch_peer_header(hash_or_number)
          cached = @lru_cache[hash_or_number]
          return cached if cached

          until header_queue.empty?
            header = receive_header
            @lru_cache[header.number] = header
            @lru_cache[header.get_hash] = header
            return header if header.number == hash_or_number || header.get_hash == hash_or_number
          end
          peer.send_msg(GetBlockHeaders, hash_or_number: HashOrNumber.new(hash_or_number), amount: HEADER_FETCH_COUNT,
                        skip: 0, reverse: false)
          while (header = receive_header_in(10))
            @lru_cache[header.number] = header
            @lru_cache[header.get_hash] = header
            return header if header.number == hash_or_number || header.get_hash == hash_or_number
          end
          raise 'should not touch here'
        end

        def fetch_peer_body(hashes)
          # clear body queue for receive
          body_queue.clear
          peer.send_msg(GetBlockBodies, hashes: hashes)
          receive_body_in(10)
        end
      end

      attr_reader :chain

      def initialize(chain:)
        @chain = chain
        @peers = {}
        super()
      end

      def receive_headers(peer, headers)
        headers.each {|header| @peers[peer].header_queue << header}
      end

      def receive_bodies(peer, bodies)
        @peers[peer].body_queue << bodies
      end

      def register_peer(peer)
        @peers[peer] = PeerEntry.new(peer)

        # request block headers if chain td less than peer
        return unless peer.total_difficulty > chain.total_difficulty
        peer.send_msg(GetBlockHeaders, hash_or_number: HashOrNumber.new(peer.status.current_block),
                      amount: 1, skip: 0, reverse: true)

        start_syncing best_peer
      end

      MAX_BLOCKS_SYNCING = 50

      # check and start syncing peer
      def start_syncing(peer)
        peer_entry = @peers[peer]
        return if peer_entry.syncing

        peer_entry.syncing = true

        executor.post do
          peer_max_header = peer_header = peer_entry.receive_header
          local_header = chain.head
          start_height = [peer_header.number, local_header.number].min

          # find common height
          while local_header.get_hash != peer_header.get_hash
            local_header = chain.get_block_by_number start_height
            peer_header = peer_entry.fetch_peer_header start_height
            start_height -= 1
          end

          loop do

            # start from common + 1 block
            start_height = local_header.number + 1

            end_height = [start_height + MAX_BLOCKS_SYNCING, peer_max_header.number].min

            if start_height < 1 || start_height > end_height
              raise 'peer is incorrect'
            end

            info "Start syncing with Peer##{peer}, from #{start_height} to #{end_height}"

            (start_height..end_height).each do |height|
              header = peer_entry.fetch_peer_header height
              bodies = peer_entry.fetch_peer_body([header.get_hash])
              block = Chain::Block.new(header: header, transactions: bodies[0].transactions, ommers: bodies[0].ommers)
              # insert to chain....
              chain.write_block(block)
              local_header = header
            end
            start_height = end_height + 1

            break if end_height >= peer_max_header.number
          end

        end
      end

      def best_peer
        @peers.keys.sort_by(&:total_difficulty).last
      end

    end

  end
end