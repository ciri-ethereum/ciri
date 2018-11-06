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


require 'async'
require 'ciri/utils/logger'

module Ciri
  module P2P

    # DialScheduler
    # establish outoging connections
    class DialScheduler
      include Utils::Logger

      def initialize(network_state, dialer)
        @network_state = network_state
        @dialer = dialer
      end

      def run(task: Async::Task.current)
        dial_bootnodes
        # dial outgoing peers every 15 seconds
        task.reactor.every(15) do
          schedule_dialing_tasks
        end
      end

      private

      def dial_bootnodes
        @network_state.peer_store.find_bootnodes(@network_state.number_of_attemp_outgoing).each do |node|
          conn, handshake = @dialer.dial(node)
          @network_state.new_peer_connected(conn, handshake, way_for_connection: Peer::OUTGOING)
        end
      end

      def schedule_dialing_tasks
        @network_state.peer_store.find_attempt_peers(@network_state.number_of_attemp_outgoing).each do |node|
          conn, handshake = @dialer.dial(node)
          @network_state.new_peer_connected(conn, handshake, way_for_connection: Peer::OUTGOING)
        end
      end
    end

  end
end

