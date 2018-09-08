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

      attr_reader :handshake, :scheduler, :protocol_manage, :protocols, :bootstrap_nodes

      def initialize(private_key:, protocol_manage:, bootstrap_nodes: [], node_name: 'Ciri')
        @private_key = private_key
        @node_name = node_name
        @bootstrap_nodes = bootstrap_nodes
        @scheduler = Scheduler.new(self)
        # TODO consider implement whisper and swarm protocols
        @protocol_manage = protocol_manage
        @protocols = protocol_manage.protocols
      end

      # return reactor to wait
      def run
        #TODO start dialer, discovery nodes and connect to them
        #TODO listen udp, for discovery protocol

        # prepare handshake information
        server_node_id = NodeID.new(@private_key)
        caps = [Cap.new(name: 'eth', version: 63)]
        @handshake = ProtocolHandshake.new(version: BASE_PROTOCOL_VERSION, name: @node_name, id: server_node_id.id, caps: caps)

        # start server
        Async::Reactor.run do |task|
          eth_protocol_task = task.async {@protocol_manage.run}
          scheduler_task = task.async {@scheduler.run}
          [eth_protocol_task, scheduler_task].each(&:wait)
        end
      end

      def setup_connection(node)
        socket = Async::IO::TCPSocket.new(node.ip, node.tcp_port)
        c = Connection.new(socket)
        c.encryption_handshake!(private_key: @private_key, node_id: node.node_id)
        remote_handshake = c.protocol_handshake!(handshake)
        [c, remote_handshake]
      end

      def protocol_handshake_checks(handshake)
        if !protocols.empty? && count_matching_protocols(protocols, handshake.caps) == 0
          raise UselessPeerError.new('discovery useless peer')
        end
      end

      def count_matching_protocols(protocols, caps)
        #TODO implement this
        1
      end

      class Scheduler

        # Discovery and dial new nodes
        class Dial
          def initialize(server)
            @server = server
            @cache = Set.new
          end

          # return new tasks to find peers
          def find_peers(running_count, peers, now)
            node = @server.bootstrap_nodes[0]
            return [] if @cache.include?(node)
            @cache << node
            connection_and_handshake = @server.setup_connection(node)
            [connection_and_handshake]
          end
        end

        include Utils::Logger
        extend Forwardable

        attr_reader :server
        def_delegators :server

        def initialize(server)
          @server = server
          @running_dialing = 0
          @peers = {}
          @dial = Dial.new(server)
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
          @dial.find_peers(@running_dialing, @peers, Time.now).each do |conn, handshake|
            new_peer_connected(conn, handshake)
          end
          @running_dialing -= 1
        end

        def register_peer_protocols(peer)
          peer.protocol_ios.each do |protocol_io|
            @server.protocol_manage.new_peer(peer, protocol_io)
          end
        end

        def new_peer_connected(connection, handshake, task: Async::Task.current)
          server.protocol_handshake_checks(handshake)
          peer = Peer.new(connection, handshake, server.protocols)
          @peers[peer.node_id] = peer
          debug "connect to new peer #{peer}"
          # run peer logic
          task.async do
            register_peer_protocols(peer)
            handling_peer(peer)
          end
        end

        def handling_peer(peer, task: Async::Task.current)
          peer.read_loop
        end

      end

    end
  end
end
