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


require 'ciri/utils/logger'

module Ciri
  module P2P

    # PeerStore store information of all peers we have seen
    #TODO rewrite with a database(sqlite)
    # Support score peers
    class PeerStore
      PEER_LAST_SEEN_VALID = 12 * 3600 # consider peer is valid if we seen it within 12 hours
      PING_EXPIRATION_IN = 10 * 60 # allow ping within 10 minutes

      # report peer behaviours
      module Behaviours
        INVALID_DATA = :invalid_data
        CONNECT = :connect
        PING = :ping
        FAILED_TO_CONNECT = :failed_to_connect
        FAILED_TO_PING = :failed_to_ping
        UNEXPECT_DISCONNECT = :unexpect_disconnect
      end

      include Behaviours

      # peer status
      module Status
        CONNECTED = :connected
        DISCONNECTED = :disconnected
        UNKNOWN = :unknown
      end

      include Status

      PEER_INITIAL_SCORE = 100
      DEFAULT_SCORE_SCHEMA = {
        INVALID_DATA => -50,
        CONNECT => 10,
        PING => 5,
        FAILED_TO_PING => -10,
        FAILED_TO_CONNECT => -10,
        UNEXPECT_DISCONNECT => -20,
      }

      def initialize(score_schema:{})
        @peers_ping_records = {}
        @peers_seen_records = {}
        @peers = {}
        @bootnodes = []
        @ban_peers = {}
        @score_schema = DEFAULT_SCORE_SCHEMA.merge(score_schema)
      end

      def has_ping?(node_id, ping_hash, expires_in: PING_EXPIRATION_IN)
        return false if has_ban?(node_id)
        record = @peers_ping_records[node_id]
        if record && record[:ping_hash] == ping_hash && (record[:ping_at] + expires_in) > Time.now.to_i
          return true
        elsif record
          @peers_ping_records.delete(node_id)
        end
        false
      end

      # record ping message
      def update_ping(node_id, ping_hash, ping_at: Time.now.to_i)
        @peers_ping_records[node_id] = {ping_hash: ping_hash, ping_at: ping_at}
      end

      def update_last_seen(node_id, at: Time.now.to_i)
        @peers_seen_records[node_id] = at
      end

      def has_seen?(node_id, expires_in: PEER_LAST_SEEN_VALID)
        return false if has_ban?(node_id)
        seen = (last_seen_at = @peers_seen_records[node_id]) && (last_seen_at + expires_in > Time.now.to_i)
        # convert to bool
        !!seen
      end

      def add_bootnode(node)
        @bootnodes << node
        add_node(node)
      end

      def has_ban?(node_id, now: Time.now)
        record = @ban_peers[node_id]
        if record && (record[:ban_at].to_i + record[:timeout_secs]) > now.to_i
          true
        else
          @ban_peers.delete(node_id)
          false
        end
      end

      def ban_peer(node_id, now: Time.now, timeout_secs:600)
        @ban_peers[node_id] = {ban_at: now, timeout_secs: timeout_secs}
      end

      def report_peer(node_id, behaviour)
        score = @score_schema[behaviour]
        raise ValueError.new("unsupport report behaviour: #{behaviour}") if score.nil?
        if (node_info = @peers[node_id])
          node_info[:score] += score
        end
      end

      # TODO find high scoring peers, use bootnodes as fallback
      def find_bootnodes(count)
        nodes = @bootnodes.sample(count)
        nodes + find_attempt_peers(count - nodes.size)
      end

      # TODO find high scoring peers
      def find_attempt_peers(count)
        @peers.values.reject do |peer_info|
          # reject already connected peers and bootnodes
          @bootnodes.include?(peer_info[:node]) || peer_status(peer_info[:node].node_id) == Status::CONNECTED
        end.sort_by do |peer_info|
          -peer_info[:score]
        end.map do |peer_info|
          peer_info[:node]
        end.take(count)
      end

      def add_node_addresses(node_id, addresses)
        node_info = @peers[node_id]
        node = node_info && node_info[:node]
        if node
          node.addresses = (node.addresses + addresses).uniq
        end
      end

      def get_node_addresses(node_id)
        peer_info = @peers[node_id]
        peer_info && peer_info[:node].addresses
      end

      def add_node(node)
        @peers[node.node_id] = {node: node, score: PEER_INITIAL_SCORE, status: Status::UNKNOWN}
      end

      def peer_status(node_id)
        if (peer_info = @peers[node_id])
          peer_info[:status]
        else
          Status::UNKNOWN
        end
      end

      def update_peer_status(node_id, status)
        if (peer_info = @peers[node_id])
          peer_info[:status] = status
        end
      end
    end

  end
end

