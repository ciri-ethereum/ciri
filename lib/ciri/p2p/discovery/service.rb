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


# TODO Items:
# [x] implement k-buckets algorithm
# [x] implement peerstore(may use sqlite)
# [ ] implement a simple scoring system
# [ ] testing
require 'async'
require 'ciri/utils/logger'
require 'ciri/p2p/node'
require 'ciri/p2p/peer_store'
require 'ciri/p2p/kad'
require_relative 'protocol'

module Ciri
  module P2P
    module Discovery

      # Implement the DiscV4 protocol
      # https://github.com/ethereum/devp2p/blob/master/discv4.md
      # notice difference between PeerStore and Kad,
      # we use PeerStore to store all peers we known(upon 8192),
      # and use Kad to store our neighbours for discovery query.
      class Service
        include Utils::Logger
        # use message classes defined in Discovery
        include Protocol

        # we should consider search from peer_store instead connect to bootnodes everytime 
        def initialize(host:, udp_port:, tcp_port:, local_node_id:, bootnodes:[], discovery_interval_secs: 15)
          @bootnodes = bootnodes
          @discovery_interval_secs = discovery_interval_secs
          @cache = Set.new
          @host = host
          @udp_port = udp_port
          @tcp_port = tcp_port
          @peer_store = PeerStore.new
          @kad_table = Kad::RoutingTable.new(local_node: Kad::Node.new(local_node_id.to_bytes))
        end

        def run(task: Async::Task.current)
          # start listening
          task.async {start_listen}
          # search peers every x seconds
          task.reactor.every(@discovery_interval_secs) do
            task.async do
              perform_discovery
            end
          end
        end

        private
        def start_listen(task: Async::Task.current)
          endpoint = Async::IO::Endpoint.udp(@host, @udp_port)
          endpoint.bind do |socket|
            @local_address = socket.local_address
            debug "start discovery server on #{@local_address.getnameinfo.join(":")}"

            loop do
              # read discovery message
              packet, address = socket.recvfrom(Discovery::Protocol::Message::MAX_LEN)
              handle_request(packet, address)
            end
          end
        end

        MESSAGE_EXPIRATION_IN = 10 * 60 # set 10 minutes later to expiration message

        def handle_request(raw_packet, address)
          msg = Message.decode_message(raw_packet)
          msg.validate
          if msg.packet.expiration < now
            trace("ignore expired message, sender: #{msg.sender}, expired_at: #{msg.packet.expiration}")
            return
          end
          case msg.packet_type
          when Ping::CODE
            @kad_table.update(msg.sender.to_bytes)
            # respond pong
            pong = Pong.new(to: To.from_inet_addr(address), 
                            ping_hash: msg.message_hash, 
                            expiration: Time.now.to_i + MESSAGE_EXPIRATION_IN)
            pong_msg = Message.pack(pong).encode_message
            send_msg_to_address(pong_msg, address)
          when Pong::CODE
            # check pong
            if @peer_store.has_ping?(msg.sender.to_bytes, msg.packet.ping_hash)
              # update peer last seen
              @peer_store.update_last_seen(msg.sender.to_bytes)
            else
              @peer_store.ban_peer(msg.sender.to_bytes)
            end
          when FindNode::CODE
            unless @peer_store.has_seen?(msg.sender.to_bytes)
              send_ping_to_address(msg.sender.to_bytes, address)
              return
            end
            nodes = find_neighbours(msg.packet.target).map do |raw_node_id, addr|
              Neighbors::Node.new(ip: addr.ip, udp_port: addr.udp_port, tcp_port: addr.tcp_port, node_id: raw_node_id)
            end
            neighbors = Neighbors.new(nodes: nodes, expiration: Time.now.to_i + MESSAGE_EXPIRATION_IN)
            send_msg_to_address(Message.pack(neighbors).encode_message, address)
            @kown_peers.update_last_seen(msg.sender.to_bytes)
          when Neighbors::CODE
            @kad_table.update(msg.sender.to_bytes)
            unless @peer_store.has_seen?(msg.sender.to_bytes)
              send_msg_to_address(msg.sender.to_bytes, address)
              return
            end
            msg.packet.nodes.each do |node|
              raw_node_id = node.node_id
              address = Address.new(ip: node.ip, udp_port: node.udp_port, tcp_port: node.tcp_port)
              @peer_store.add_node(Node.new(raw_node_id: raw_node_id, addresses: [address]))
              # add new discovered node_id
              @kad_table.update(raw_node_id)
            end
            @kown_peers.update_last_seen(msg.sender.to_bytes)
          else
            @peer_store.ban_peer(msg.sender.to_bytes)
            raise UnknownMessageCodeError.new("can't handle unknown code in discovery protocol, code: #{msg.packet_type}")
          end
        rescue StandardError => e
          @peer_store.ban_peer(msg.sender.to_bytes)
          error("discovery error: #{e} from address: #{address}")
        end

        def send_ping_to_address(target_node_id, address)
          send_ping(target_node_id, address[3], address[1])
        end

        # send discover ping to peer
        def send_ping(target_node_id, host, port)
          ping = Ping.new(to: To.from_host_port(host, port), 
                          from: From.new(
                            sender_ip: IPAddr.new(@host).to_i,
                            sender_udp_port: @udp_port,
                            sender_tcp_port: @tcp_port),
                            expiration: Time.now.to_i + MESSAGE_EXPIRATION_IN)
          ping_msg = Message.pack(ping).encode_message
          send_msg(ping_msg, host, port)
          @peer_store.update_ping(target_node_id, ping_msg.message_hash)
        end

        def send_msg_to_address(msg, address)
          send_msg(address[3], address[1])
        end

        def send_msg(msg, host, port)
          socket = Async::IO::UDPSocket.new
          socket.send(msg, 0, host, port)
        end

        # find nerly neighbours
        def find_neighbours(raw_node_id, count)
          @kad_table.find_neighbours(raw_node_id, k: count).map do |node|
            [raw_node_id, @peer_store.get_node_addresses(raw_node_id)&.first]
          end.delete_if(&:nil?)
        end

        def perform_discovery(count_of_query_nodes=15, task: Async::Task.current)
          query_target = NodeID.new(Key.random).id
          # randomly search
          @kad_table.get_random_nodes(15).each do |node|
            address = @peer_store.get_node_addresses(node.raw_node_id)&.first
            next unless address
            # start query node in async task
            task.async do
              send_ping(node.raw_node_id, address.ip, address.udp_port)
              query = FindNode.new(target: query_target, expiration: Time.now.to_i + MESSAGE_EXPIRATION_IN)
              query_msg = Message.pack(query).encode_message
              send_msg(query_msg, address.ip, address.udp_port)
            end
          end
        end
      end

    end
  end
end

