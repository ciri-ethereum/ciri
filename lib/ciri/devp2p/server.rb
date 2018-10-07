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
require 'async/io'
require 'async/io/tcp_socket'
require 'forwardable'
require 'ciri/utils/logger'
require_relative 'rlpx/connection'
require_relative 'rlpx/protocol_handshake'
require_relative 'errors'
require_relative 'peer'
require_relative 'network_state'
require_relative 'dialer'
require_relative 'discovery_service'
require_relative 'dial_scheduler'

module Ciri
  module DevP2P

    # DevP2P Server
    # maintain connection, node discovery, rlpx handshake and protocols
    class Server
      include Utils::Logger
      include RLPX

      DEFAULT_MAX_PENDING_PEERS = 50
      DEFAULT_DIAL_RATIO = 3

      attr_reader :handshake, :dial_scheduler, :protocol_manage, :dialer, :local_address

      def initialize(private_key:, protocol_manage:, bootnodes: [],
                     node_name: 'Ciri', host: '127.0.0.1', port: 33033)
        @private_key = private_key
        @node_name = node_name
        @protocol_manage = protocol_manage
        # prepare handshake information
        server_node_id = NodeID.new(@private_key)
        caps = [Cap.new(name: 'eth', version: 63)]
        @handshake = ProtocolHandshake.new(version: BASE_PROTOCOL_VERSION, name: @node_name, id: server_node_id.id, caps: caps)
        @host = host
        @port = port
        @dialer = Dialer.new(private_key: private_key, handshake: @handshake)
        @network_state = NetworkState.new(protocol_manage)
        @bootnodes = bootnodes
      end

      # return reactor to wait
      def run
        #TODO start discovery
        #TODO listen udp, for discovery protocol

        # start server and services
        Async::Reactor.run do |task|
          # wait sub tasks
          task.async do
            # start ETH protocol, @protocol_manage is basicly ETH protocol now
            task.async {@protocol_manage.run}
            task.async do
              # Wait for server started listen
              # we use listened port to start DiscoveryService to allow 0 port
              task.sleep(0.5) until @local_address

              # start discovery service
              @discovery_service = DiscoveryService.new(bootnodes: @bootnodes, host: @host, port: @local_address.ip_port)
              task.async { @discovery_service.run }

              # start dial outgoing nodes
              @dial_scheduler = DialScheduler.new(@network_state, @dialer, @discovery_service)
              task.async {@dial_scheduler.run}
            end
            task.async {start_listen}
          end.wait
        end
      end

      # start listen and accept clients
      def start_listen(task: Async::Task.current)
        endpoint = Async::IO::Endpoint.tcp(@host, @port)
        endpoint.bind do |socket|
          @local_address = socket.local_address
          info("start accept connections -- listen on #{@local_address.getnameinfo.join(":")}")
          socket.listen(Socket::SOMAXCONN)
          socket.accept_each do |client|
            c = Connection.new(client)
            c.encryption_handshake!(private_key: @private_key)
            remote_handshake = c.protocol_handshake!(handshake)
            @network_state.new_peer_connected(c, remote_handshake)
          end
        end
      end

    end
  end
end

