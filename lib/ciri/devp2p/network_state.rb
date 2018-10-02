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
require_relative 'peer'
require_relative 'error'

module Ciri
  module DevP2P

    # NetworkState
    # maintaining current connected peers
    class NetworkState
      include Utils::Logger

      attr_reader :peers, :caps

      def initialize(protocol_manage, ping_interval_secs: 15)
        @peers = {}
        @protocol_manage = protocol_manage
        @ping_interval_secs = ping_interval_secs
      end

      def new_peer_connected(connection, handshake, task: Async::Task.current)
        protocol_handshake_checks(handshake)
        peer = Peer.new(connection, handshake, @protocol_manage.protocols)
        @peers[peer.id] = peer
        debug "connect to new peer #{peer}"
        # run peer logic
        task.async do
          register_peer_protocols(peer)
          handling_peer(peer)
        end
      end

      def remove_peer(peer)
        @peers.delete(peer.id)
        deregister_peer_protocols(peer)
      end

      private

      def register_peer_protocols(peer)
        peer.protocol_ios.each do |protocol_io|
          @protocol_manage.new_peer(peer, protocol_io)
        end
      end

      def deregister_peer_protocols(peer)
        @protocol_manage.remove_peer(peer)
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
        ping_timer = task.reactor.every(@ping_interval_secs) do
          ping(peer)
        end

        message_service = task.async do
          loop do
            raise DisconnectError.new("disconnect peer") if @disconnect
            msg = peer.connection.read_msg
            msg.received_at = Time.now
            handle_message(peer, msg)
          end
        end

        message_service.wait
      rescue StandardError => e
        # clear up
        ping_timer.cancel
        message_service.stop if message_service&.running?
        peer.disconnect unless peer.disconnected?
        # raise error
        raise
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
      def handle_message(peer, msg)
        if msg.code == RLPX::Code::PING
          pong
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
          protocol_io.receive_msg msg
        end
      end

      def protocol_handshake_checks(handshake)
        if @protocol_manage.protocols && count_matching_protocols(handshake.caps) == 0
          raise UselessPeerError.new('discovery useless peer')
        end
      end

      # {cap_name => cap_version}
      def caps_hash
        @caps_hash ||= @protocol_manage.protocols.sort_by do |cap|
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

