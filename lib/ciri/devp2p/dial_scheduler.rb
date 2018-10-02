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
  module DevP2P

    # DialScheduler
    # establish outoging connections
    class DialScheduler
      include Utils::Logger

      MAX_ACTIVE_DIAL_TASKS = 16

      def initialize(network_state, dialer, discovery_service)
        @network_state = network_state
        @running_dialing = 0
        @dialer = dialer
        @discovery_service = discovery_service
      end

      def run(task: Async::Task.current)
        schedule_dialing_tasks
        # search peers every 15 seconds
        task.reactor.every(15) do
          schedule_dialing_tasks
        end
      end

      private

      def schedule_dialing_tasks
        return unless @running_dialing < MAX_ACTIVE_DIAL_TASKS
        @running_dialing += 1
        @discovery_service.find_peers(@running_dialing, @network_state.peers, Time.now).each do |node|
          conn, handshake = @dialer.dial(node)
          @network_state.new_peer_connected(conn, handshake)
        end
        @running_dialing -= 1
      end
    end

  end
end

