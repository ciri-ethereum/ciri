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
require_relative 'peer'

module Ciri
  module DevP2P

    # DevP2P Server
    # maintain connection, node discovery, rlpx handshake and protocols
    class Server
      include Utils::Logger
      include RLPX

      MAX_ACTIVE_DIAL_TASKS = 16
      DEFAULT_MAX_PENDING_PEERS = 50
      DEFAULT_DIAL_RATIO = 3

      class Error < StandardError
      end
      class UselessPeerError < Error
      end

      attr_reader :handshake, :scheduler, :protocol_manage, :bootstrap_nodes, :dial

      def initialize(private_key:, protocol_manage:, bootstrap_nodes: [],
                     node_name: 'Ciri', tcp_host: '127.0.0.1', tcp_port: 33033)
        @private_key = private_key
        @node_name = node_name
        @bootstrap_nodes = bootstrap_nodes
        # TODO consider implement whisper and swarm protocols
        @protocol_manage = protocol_manage
        # prepare handshake information
        server_node_id = NodeID.new(@private_key)
        caps = [Cap.new(name: 'eth', version: 63)]
        @handshake = ProtocolHandshake.new(version: BASE_PROTOCOL_VERSION, name: @node_name, id: server_node_id.id, caps: caps)
        @tcp_host = tcp_host
        @tcp_port = tcp_port
        @dial = Dial.new(bootstrap_nodes: bootstrap_nodes, private_key: private_key, handshake: @handshake)
        @network_state = NetworkState.new(protocol_manage)
        @scheduler = Scheduler.new(@network_state, @dial)
      end

      # return reactor to wait
      def run
        #TODO start dialer, discovery nodes and connect to them
        #TODO listen udp, for discovery protocol

        # start server
        Async::Reactor.run do |task|
          # wait sub tasks
          task.async do
            task.async {@protocol_manage.run}
            task.async {@scheduler.run}
            task.async {start_accept}
          end.wait
        end
      end

      # start listen and accept clients
      def start_accept(task: Async::Task.current)
        endpoint = Async::IO::Endpoint.tcp(@tcp_host, @tcp_port)
        info("start accept connections -- listen on #@tcp_host:#@tcp_port")
        endpoint.accept do |client|
          c = Connection.new(client)
          c.encryption_handshake!(private_key: @private_key)
          remote_handshake = c.protocol_handshake!(handshake)
          @network_state.new_peer_connected(c, remote_handshake)
        end
      end

      class NetworkState
        include Utils::Logger

        attr_reader :peers

        def initialize(protocol_manage)
          @protocol_manage = protocol_manage
          @peers = {}
        end

        def register_peer_protocols(peer)
          peer.protocol_ios.each do |protocol_io|
            @protocol_manage.new_peer(peer, protocol_io)
          end
        end

        def deregister_peer_protocols(peer)
          @protocol_manage.remove_peer(peer)
        end

        def new_peer_connected(connection, handshake, task: Async::Task.current)
          protocol_handshake_checks(handshake)
          peer = Peer.new(connection, handshake, @protocol_manage.protocols)
          @peers[peer.node_id] = peer
          debug "connect to new peer #{peer}"
          # run peer logic
          task.async do
            register_peer_protocols(peer)
            handling_peer(peer)
          end
        end

        def remove_peer(peer)
          @peers.delete(peer.node_id)
          deregister_peer_protocols(peer)
        end

        private

        def handling_peer(peer, task: Async::Task.current)
          peer.start_handling
        rescue Exception => e
          remove_peer(peer)
          error("remove peer #{peer}, error: #{e}")
        end

        def protocol_handshake_checks(handshake)
          if @protocol_manage.protocols && count_matching_protocols(@protocol_manage.protocols, handshake.caps) == 0
            raise UselessPeerError.new('discovery useless peer')
          end
        end

        def count_matching_protocols(protocols, caps)
          #TODO implement this
          1
        end
      end

      # Discovery and dial new nodes
      class Dial
        include RLPX

        def initialize(bootstrap_nodes: [], private_key:, handshake:)
          @bootstrap_nodes = bootstrap_nodes
          @private_key = private_key
          @handshake = handshake
          @cache = Set.new
        end

        # return new tasks to find peers
        def find_peers(running_count, peers, now)
          node = @bootstrap_nodes.sample
          return [] if @cache.include?(node)
          @cache << node
          connection_and_handshake = setup_connection(node)
          [connection_and_handshake]
        end

        # setup a new connection to node
        def setup_connection(node)
          # connect tcp socket
          # Async::IO::Stream provide synchronize read interface, so we wrap async socket into it.
          socket = Async::IO::Stream.new(Async::IO::Endpoint.tcp(node.ip, node.tcp_port).connect, block_size: 0)
          c = Connection.new(socket)
          c.encryption_handshake!(private_key: @private_key, remote_node_id: node.node_id)
          remote_handshake = c.protocol_handshake!(@handshake)
          [c, remote_handshake]
        end
      end

      class Scheduler
        include Utils::Logger

        def initialize(network_state, dial)
          @network_state = network_state
          @running_dialing = 0
          @peers = {}
          @dial = dial
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
          @dial.find_peers(@running_dialing, @network_state.peers, Time.now).each do |conn, handshake|
            @network_state.new_peer_connected(conn, handshake)
          end
          @running_dialing -= 1
        end
      end

    end
  end
end
