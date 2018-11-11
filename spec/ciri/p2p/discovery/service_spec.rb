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


require 'ciri/p2p/discovery/service'

RSpec.describe Ciri::P2P::Discovery::Service do

  def new_service(peer_store: Ciri::P2P::PeerStore.new, discovery_interval_secs: 1)
    Ciri::P2P::Discovery::Service.new(
      peer_store: peer_store,
      host: '127.0.0.1',
      udp_port: 0,
      tcp_port: 0,
      private_key: Ciri::Key.random,
      discovery_interval_secs: discovery_interval_secs,
    )
  end

  context 'ping' do
    it 'perform ping/pong' do
      Async::Reactor.run do |task|
        # set a large interval to disable performing discovery
        interval = 1000
        s1 = new_service(discovery_interval_secs: interval)
        s2 = new_service(discovery_interval_secs: interval)

        task.async { s1.run }
        task.async { s2.run }

        # how to avoid time dependency?
        task.reactor.after(0.1) do
          expect(s1.peer_store.has_seen?(s2.local_node_id.to_bytes)).to be_falsey
          s1.send(:send_ping, s2.local_node_id.to_bytes, s2.host, s2.udp_port)
        end

        task.reactor.after(0.2) do
          expect(s1.peer_store.has_seen?(s2.local_node_id.to_bytes)).to be_truthy
          task.reactor.stop
        end
      end
    end

    it 'auto perform ping/pong if not seen peer'
  end

  context 'discovery' do
    it 'discovery 3rd peer'
  end
end

