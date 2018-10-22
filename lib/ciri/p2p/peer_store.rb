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

      module Behaviours
      end

      def initialize
        @peers_ping_records = {}
        @peers = {}
      end

      def has_ping?(raw_node_id, ping_hash, expires_in: PING_EXPIRATION_IN)
        record = @peers_ping_records[raw_node_id]
        if record && record[:ping_hash] == ping_hash && (record[:ping_at] + expired_in) > Time.now.to_i
          return true
        elsif record
          @peers_ping_records.delete(raw_node_id)
        end
        false
      end

      # record ping message
      def update_ping(raw_node_id, ping_hash, ping_at: Time.now.to_i)
        @peers_ping_records[raw_node_id] = {ping_hash: ping_hash, ping_at: ping_at}
      end

      def update_last_seen(raw_node_id, at: Time.now.to_i)
        @peers[raw_node_id] = at
      end

      def has_seen?(raw_node_id, expires_in: PEER_LAST_SEEN_VALID)
        seen = (last_seen_at = @peers[raw_node_id]) && (last_seen_at + expires_in > Time.now.to_i)
        # convert to bool
        !!seen
      end
    end

  end
end

