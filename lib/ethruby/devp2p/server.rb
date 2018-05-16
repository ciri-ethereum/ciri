# frozen_string_literal: true

require 'concurrent'
require 'forwardable'
require_relative 'rlpx/connection'
require_relative 'rlpx/protocol_handshake'
require_relative 'peer'
require_relative 'actor'

module ETH
  module DevP2P

    # DevP2P Server
    # maintain connection, node discovery, rlpx handshake and protocols
    class Server
      include RLPX

      MAX_ACTIVE_DIAL_TASKS = 16
      DEFAULT_MAX_PENDING_PEERS = 50
      DEFAULT_DIAL_RATIO = 3

      class Error < StandardError
      end
      class UselessPeerError < Error
      end

      attr_reader :handshake, :dial, :scheduler
      attr_accessor :logger, :bootstrap_nodes, :protocols

      def initialize(private_key:)
        @private_key = private_key
        @name = 'ethruby'
        @scheduler = Scheduler.new(self)
        @protocols = []
      end

      def start
        #TODO start dialer, discovery nodes and connect to them
        #TODO listen udp, for discovery protocol

        server_node_id = NodeID.new(@private_key)
        caps = [Cap.new(name: 'eth', version: 63)]
        @handshake = ProtocolHandshake.new(version: BASE_PROTOCOL_VERSION, name: @name, id: server_node_id.id, caps: caps)
        # start listen tcp
        @dial = Dial.new(self)
        @scheduler.start
      end

      def setup_connection(node)
        socket = TCPSocket.new(node.ip, node.tcp_port)
        c = Connection.new(socket)
        c.encryption_handshake!(private_key: @private_key, node_id: node.node_id)
        remote_handshake = c.protocol_handshake!(handshake)
        scheduler << [:add_peer, c, remote_handshake]
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

      # scheduler task
      class Task
        attr_reader :name

        def initialize(name:, &blk)
          @name = name
          @blk = blk
        end

        def call(*args)
          @blk.call(*args)
        end
      end

      # Discovery and dial new nodes
      class Dial
        def initialize(server)
          @server = server
          @cache = []
        end

        # return new tasks to find peers
        def find_peer_tasks(running_count, peers, now)
          node = @server.bootstrap_nodes[0]
          return [] if @cache.include?(node)
          @cache << node
          [Task.new(name: 'find peer') {
            @server.setup_connection(node)
          }]
        end
      end

      class Scheduler
        include Actor

        extend Forwardable

        attr_reader :server
        def_delegators :server, :logger

        def initialize(server)
          @server = server
          @queued_tasks = []
          @running_tasks = []
          @peers = {}
          executor = Concurrent::CachedThreadPool.new
          # init actor
          super(executor: executor)
        end

        # called by actor loop
        def loop_callback
          schedule_tasks
          yield
        end

        def start_tasks(tasks)
          tasks = tasks.dup
          while @running_tasks.size < MAX_ACTIVE_DIAL_TASKS
            break unless (task = tasks.pop)
            executor.post(task) do |task|
              task.call
              self << [:task_done, task]
            end
            @running_tasks << task
          end
          tasks
        end

        # invoke tasks, and prepare search peer tasks
        def schedule_tasks
          @queued_tasks = start_tasks(@queued_tasks)
          if @queued_tasks.size < MAX_ACTIVE_DIAL_TASKS
            tasks = server.dial.find_peer_tasks(@running_tasks.size + @queued_tasks.size, @peers, Time.now)
            @queued_tasks += tasks
          end
        end

        private
        def add_peer(connection, handshake)
          server.protocol_handshake_checks(handshake)
          peer = Peer.new(connection, handshake, server.protocols)
          # set actor executor
          peer.executor = executor
          @peers[peer.node_id] = peer
          # run peer logic
          # do sub protocol handshake...
          executor.post {
            peer.start

            exit_error = nil
            begin
              peer.wait
            rescue StandardError => e
              exit_error = e
            end
            # remove peer
            self << [:remove_peer, peer, exit_error]
          }
          logger.debug("add peer: #{peer}")
        end

        def remove_peer(peer, *args)
          error, * = args
          logger.debug("remove peer: #{peer}, error: #{error}")
        end

        def task_done(task, *args)
          logger.debug("task done: #{task.name}")
        end

      end

    end
  end
end
