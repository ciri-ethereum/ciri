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
require 'async/semaphore'
require 'ciri/utils/logger'
require_relative 'peer'
require_relative 'errors'
require_relative 'protocol_context'

module Ciri
  module P2P

    # NetworkState
    # maintaining current connected peers
    class NetworkState
      include Utils::Logger

      attr_reader :peers, :caps, :peer_store, :local_node_id

      def initialize(protocols:, peer_store:, local_node_id:, max_outgoing: 10, max_incoming: 10, ping_interval_secs: 15)
        @peers = {}
        @peers_lock = Async::Semaphore.new
        @peer_store = peer_store
        @protocols = protocols
        @local_node_id = local_node_id
        @max_outgoing = max_outgoing
        @max_incoming = max_incoming
        @ping_interval_secs = ping_interval_secs
      end

      def initialize_protocols(task: Async::Task.current)
        # initialize protocols
        @protocols.each do |protocol|
          context = ProtocolContext.new(self, protocol: protocol)
          task.async {protocol.initialized(context)}
        end
      end

      def number_of_attemp_outgoing
        @max_outgoing - @peers.values.select(&:outgoing?).count
      end

      def new_peer_connected(connection, handshake, direction:, task: Async::Task.current)
        @peers_lock.acquire do
          peer = Peer.new(connection, handshake, @protocols, direction: direction)
          # disconnect already connected peers
          if @peers.include?(peer.node_id)
            debug("[#{local_node_id.short_hex}] peer #{peer.inspect} is already connected")
            # disconnect duplicate connection
            peer.disconnect
            return
          end
          # check peers
          protocol_handshake_checks(handshake)
          @peers[peer.node_id] = peer
          info "[#{local_node_id.short_hex}] connect to new peer #{peer.inspect}"
          @peer_store.update_peer_status(peer.node_id, PeerStore::Status::CONNECTED)
          # run peer logic
          task.async do
            register_peer_protocols(peer)
            handling_peer(peer)
          end
        end
      end

      def disconnect_peer(peer, reason: nil)
        @peers_lock.acquire do
          # only disconnect from peers if direction correct to avoiding delete peer by mistake
          if (exist_peer = @peers[peer.node_id]) && exist_peer.direction == peer.direction
            info("[#{local_node_id.short_hex}] disconnect peer: #{peer.inspect}, reason: #{reason}")
            remove_peer(peer)
            peer.disconnect
            @peer_store.update_peer_status(peer.node_id, PeerStore::Status::DISCONNECTED)
          else
            debug("[#{local_node_id.short_hex}] Ignoring: disconnect peer: #{peer.inspect}, reason: #{reason}")
          end
        end
      end

      def disconnect_all
        debug("[#{local_node_id.short_hex}] disconnect all")
        peers.each_value do |peer|
          disconnect_peer(peer, reason: "disconnect all...")
        end
      end

      private

      def remove_peer(peer)
        @peers.delete(peer.node_id)
        deregister_peer_protocols(peer)
      end


      def register_peer_protocols(peer, task: Async::Task.current)
        peer.protocol_ios.dup.each do |protocol_io|
          task.async do
            # Protocol#connected
            context = ProtocolContext.new(self, peer: peer, protocol: protocol_io.protocol, protocol_io: protocol_io)
            context.protocol.connected(context)
          rescue StandardError => e
            error("Protocol#connected error: #{e}\nbacktrace: #{e.backtrace.join "\n"}")
            disconnect_peer(peer, reason: "Protocol#connected callback error: #{e}")
          end
        end
      end

      def deregister_peer_protocols(peer, task: Async::Task.current)
        peer.protocol_ios.dup.each do |protocol_io|
          task.async do
            # Protocol#connected
            context = ProtocolContext.new(self, peer: peer, protocol: protocol_io.protocol, protocol_io: protocol_io)
            context.protocol.disconnected(context)
          rescue StandardError => e
            error("Protocol#disconnected error: {e}\nbacktrace: #{e.backtrace.join "\n"}")
            disconnect_peer(peer, reason: "Protocol#disconnected callback error: #{e}")
          end
        end
      end

      # handling peer IO
      def handling_peer(peer, task: Async::Task.current)
        start_peer_io(peer)
      rescue Exception => e
        remove_peer(peer)
        error("remove peer #{peer}, error: #{e}")
      end

      # starting peer IO loop
      def start_peer_io(peer, task: Async::Task.current)
        _ping_timer = task.reactor.every(@ping_interval_secs) do
          task.async do
            ping(peer)
          rescue StandardError => e
            disconnect_peer(peer, reason: "ping error: #{e}")
          end
        end

        message_service = task.async do
          loop do
            raise DisconnectError.new("disconnect peer") if @disconnect
            msg = peer.connection.read_msg
            msg.received_at = Time.now
            handle_message(peer, msg)
          end
        rescue StandardError => e
          disconnect_peer(peer, reason: "io error: #{e}")
          error("io error: #{e}\n#{e.backtrace.join "\n"}")
        end

        message_service.wait
      end

      BLANK_PAYLOAD = RLP.encode([]).freeze

      # response pong to message
      def ping(peer)
        peer.connection.send_data(RLPX::Code::PING, BLANK_PAYLOAD)
      end

      # response pong to message
      def pong(peer)
        peer.connection.send_data(RLPX::Code::PONG, BLANK_PAYLOAD)
      end

      # handle peer message
      def handle_message(peer, msg, task: Async::Task.current)
        if msg.code == RLPX::Code::PING
          pong(peer)
        elsif msg.code == RLPX::Code::DISCONNECT
          reason = RLP.decode_with_type(msg.payload, Integer)
          raise DisconnectError.new("receive disconnect message, reason: #{reason}")
        elsif msg.code == RLPX::Code::PONG
          # TODO update peer node
        else
          # send msg to sub protocol
          if (protocol_io = peer.find_protocol_io_by_msg_code(msg.code)).nil?
            raise UnknownMessageCodeError.new("can't find protocol with msg code #{msg.code}")
          end
          # fix msg code
          msg.code -= protocol_io.offset
          task.async do
            # Protocol#received
            context = ProtocolContext.new(self, peer: peer, protocol: protocol_io.protocol, protocol_io: protocol_io)
            context.protocol.received(context, msg)
          end
        end
      end

      def protocol_handshake_checks(handshake)
        if @protocols && count_matching_protocols(handshake.caps) == 0
          raise UselessPeerError.new('discovery useless peer')
        end
      end

      # {cap_name => cap_version}
      def caps_hash
        @caps_hash ||= @protocols.sort_by do |cap|
          cap.version
        end.reduce({}) do |caps_hash, cap|
          caps_hash[cap.name] = cap.version
          caps_hash
        end
      end

      # calculate count of matched protocols caps
      def count_matching_protocols(caps)
        caps.select do |cap|
          caps_hash[cap.name] == cap.version
        end.count
      end
    end

  end
end

