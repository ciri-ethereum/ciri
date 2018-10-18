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


require 'ciri/utils/logger'
require 'ciri/key'
require 'ciri/rlp'
require 'ciri/devp2p/node'
require 'ciri/devp2p/errors'
require 'ipaddr'

module Ciri
  module DevP2P

    # implement the DiscV4 protocol
    # https://github.com/ethereum/devp2p/blob/master/discv4.md
    module Discovery
      class Message

        MAX_LEN=1280

        attr_reader :message_hash, :packet_type, :packet_data

        def initialize(message_hash:, signature:, packet_type:, packet_data:)
          @message_hash = message_hash
          @signature = signature
          @packet_type = packet_type
          @packet_data = packet_data
        end

        # compute key and return NodeID
        def sender
          @sender ||= begin
                        encoded_packet_type = Utils.big_endian_encode(packet_type)
                        public_key = Key.ecdsa_recover(Utils.keccak(encoded_packet_type + packet_data), @signature)
                        NodeID.new(public_key)
                      end
        end

        def packet
          packet_class = case @packet_type
                         when Ping::CODE
                           Ping
                         when Pong::CODE
                           Pong
                         when FindNode::CODE
                           FindNode
                         when Neighbors::CODE
                           Neighbors
                         else
                           raise UnknownMessageCodeError.new("unkonwn discovery message code: #{@packet_type}")
                         end
          # TODO according discv4 protocol, rlp_decode should support ignore additional elements
          # we should support ignore_extra_data option in Ciri::RLP
          packet_class.rlp_decode @packet_data
        end

        # validate message hash and signature
        def validate
          raise InvalidMessageError.new("mismatch hash") if message_hash != Utils.keccak(signature + packet_type + packet_data)
          begin
            sender
          rescue StandardError => e
            raise InvalidMessageError.new("recover sender error: #{e}")
          end
        end

        # encode message to string
        def encode_message
          buf = String.new
          buf << message_hash
          buf << @signature
          buf << packet_type
          buf << packet_data
          buf
        end

        class << self
          # return a Message
          def decode_message(raw_bytes)
            hash = raw_bytes[0...32]
            # signature is 65 length r,s,v
            signature = raw_bytes[32...97]
            packet_type = Utils.big_endian_decode raw_bytes[97]
            packet_data = raw_bytes[98..-1]
            Message.new(message_hash: hash, signature: signature, packet_type: packet_type, packet_data: packet_data)
          end

          # return a new message instance include packet
          def pack(packet, private_key:)
            packet_data = Ciri::RLP.encode(packet)
            packet_type = packet.class.code
            encoded_packet_type = Utils.big_endian_encode(packet_type)
            signature = private_key.ecdsa_signature(Utils.keccak(encoded_packet_type + packet_data)).to_s
            hash = Utils.keccak(signature + encoded_packet_type + packet_data)
            if (msg_size=hash.size + signature.size + encoded_packet_type.size + packet_data.size) > MAX_LEN
              raise InvalidMessageError.new("failed to pack, message size is too long, size: #{msg_size}, max_len: #{MAX_LEN}")
            end
            Message.new(message_hash: hash, signature: signature, packet_type: packet_type, packet_data: packet_data)
          end
        end
      end

      # a struct represent which node send this packet
      class From
        include Ciri::RLP::Serializable

        # we should not trust the sender_ip field
        schema(
          sender_ip: Integer,
          sender_udp_port: Integer,
          sender_tcp_port: Integer,
        )
      end

      # a struct represent which node is target of this packet
      class To
        include Ciri::RLP::Serializable

        # because discv4 protocol has not give us a name of last field,
        # we just keep the field value 0 and guess it name should be recipient_tcp_port
        # https://github.com/ethereum/devp2p/blob/master/discv4.md#ping-packet-0x01

        schema(
          recipient_ip: Integer,
          recipient_udp_port: Integer,
          recipient_tcp_port: Integer,
        )
        default_data(recipient_tcp_port: 0)

        class << self
          def from_inet_addr(address)
            from_host_port(address[3], address[1])
          end

          def from_host_port(host, port)
            new(recipient_ip: IPAddr.new(host).to_i, recipient_udp_port: port)
          end
        end
      end

      # abstract class
      class Packet
        def self.code
          self::CODE
        end
      end

      class Ping < Packet
        include Ciri::RLP::Serializable

        CODE = 0x01

        schema(
          version: Integer,
          from: From,
          to: To,
          expiration: Integer,
        )

        default_data(version: 0)
      end

      class Pong < Packet
        include Ciri::RLP::Serializable

        CODE = 0x02

        schema(
          to: To,
          ping_hash: RLP::Bytes,
          expiration: Integer,
        )
      end

      class FindNode < Packet
        include Ciri::RLP::Serializable

        CODE = 0x03

        schema(
          target: RLP::Bytes,
          expiration: Integer,
        )
      end

      class Neighbors < Packet
        include Ciri::RLP::Serializable

        CODE = 0x04

        # neighbour info
        class Node
          include Ciri::RLP::Serializable

          schema(
            ip: Integer,
            udp_port: Integer,
            tcp_port: Integer,
            node_id: RLP::Bytes,
          )
        end

        schema(
          nodes: [Node],
          expiration: Integer,
        )
      end

    end

  end
end

