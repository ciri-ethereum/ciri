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
require_relative 'discovery/service'
require_relative 'dial_scheduler'

module Ciri
  module P2P

    # P2P Server
    # maintain connection, node discovery, rlpx handshake
    class Server
      include Utils::Logger
      include RLPX
      extend Forwardable

      DEFAULT_MAX_PENDING_PEERS = 50
      DEFAULT_DIAL_RATIO = 3

      attr_reader :handshake, :dial_scheduler, :dialer, :local_address, :tcp_port
      
      def_delegators :@network_state, :disconnect_all

      def initialize(private_key:, protocols:, bootnodes: [],
                     node_name: 'Ciri', host: '127.0.0.1',
                     tcp_port: 33033, udp_port: 33033,
                     max_outgoing: 10, max_incoming:10,
                     ping_interval_secs: 15,
                     discovery_interval_secs: 15,
                     dial_outgoing_interval_secs: 25)
        @private_key = private_key
        @node_name = node_name
        # prepare handshake information
        @local_node_id = NodeID.new(@private_key)
        caps = protocols.map do |protocol|
          Cap.new(name: protocol.name, version: protocol.version)
        end
        @handshake = ProtocolHandshake.new(version: BASE_PROTOCOL_VERSION, name: @node_name, id: @local_node_id.to_bytes, caps: caps)
        @host = host
        @tcp_port = tcp_port
        @udp_port = udp_port
        @dialer = Dialer.new(private_key: private_key, handshake: @handshake)
        @peer_store = PeerStore.new
        @network_state = NetworkState.new(
          protocols: protocols,
          peer_store: @peer_store,
          local_node_id: @local_node_id,
          max_incoming: max_incoming,
          max_outgoing: max_outgoing,
          ping_interval_secs: ping_interval_secs)
        @bootnodes = bootnodes
        @discovery_interval_secs = discovery_interval_secs
        @dial_outgoing_interval_secs = dial_outgoing_interval_secs
      end

      def udp_port
        @discovery_service&.udp_port || @udp_port
      end

      def to_node
        address = Address.new(ip: @host, tcp_port: tcp_port, udp_port: udp_port)
        Node.new(node_id: @local_node_id, addresses: [address])
      end

      # return reactor to wait
      def run
        # setup bootnodes
        @bootnodes.each do |node|
          @peer_store.add_bootnode(node)
        end

        # start server and services
        Async::Reactor.run do |task|
          # initialize protocols
          @network_state.initialize_protocols
          # wait sub tasks
          task.async do
            task.async do
              # Wait for server started listen
              # we use listened port to start DiscoveryService to allow 0 port
              task.sleep(0.5) until @local_address

              # start discovery service
              @discovery_service = Discovery::Service.new(
                peer_store: @peer_store,
                private_key: @private_key,
                host: @host, udp_port: @udp_port, tcp_port: @tcp_port,
                discovery_interval_secs: @discovery_interval_secs)
              task.async { @discovery_service.run }

              # start dial outgoing nodes
              @dial_scheduler = DialScheduler.new(
                @network_state,
                @dialer,
                dial_outgoing_interval_secs: @dial_outgoing_interval_secs)
              task.async {@dial_scheduler.run}
            end
            task.async {start_listen}
          end.wait
        end
      end

      # start listen and accept clients
      def start_listen(task: Async::Task.current)
        endpoint = Async::IO::Endpoint.tcp(@host, @tcp_port)
        endpoint.bind do |socket|
          @local_address = socket.local_address
          info("start accept connections -- listen on #{@local_address.getnameinfo.join(":")}")
          # update tcp_port if it is 0
          if @tcp_port.zero?
            @tcp_port = @local_address.ip_port
          end
          socket.listen(Socket::SOMAXCONN)
          loop do
            client, _addrinfo = socket.accept
            c = Connection.new(client)
            c.encryption_handshake!(private_key: @private_key)
            remote_handshake = c.protocol_handshake!(handshake)
            @network_state.new_peer_connected(c, remote_handshake, direction: Peer::INBOUND)
          end
        end
      end

    end
  end
end

