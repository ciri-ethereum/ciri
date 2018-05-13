# frozen_string_literal: true

require 'ethruby/rlp'
require 'socket'
require 'forwardable'
require_relative 'frame_io'
require_relative 'protocol_messages'
require_relative 'error'
require_relative 'encryption_handshake'

module ETH
  module DevP2P
    module RLPX

      # RLPX::Connection implement RLPX protocol operations
      # all operations end with bang(!)
      class Connection
        extend Forwardable

        def_delegators :@frame_io, :read_msg, :write_msg, :send_data

        class Error < RLPX::Error
        end

        class MessageOverflowError < Error
        end

        class UnexpectedMessageError < Error
        end

        class FormatError < Error
        end

        def initialize(io)
          set_timeout(io)
          @io = io
          @frame_io = nil
        end

        # Encryption handshake, exchange keys with node, must been invoked before other operations
        def encryption_handshake!(private_key:, node_id: nil)
          enc_handshake = EncryptionHandshake.new(private_key: private_key, remote_id: node_id)
          secrets = node_id.nil? ? receiver_enc_handshake(enc_handshake) : initiator_enc_handshake(enc_handshake)
          @frame_io = FrameIO.new(@io, secrets)
        end

        # protocol handshake
        def protocol_handshake!(our_hs)
          @frame_io.send_data(MESSAGES[:handshake], our_hs.rlp_encode!)
          remote_hs = read_protocol_handshake
          # enable snappy compress if remote peer support
          @frame_io.snappy = remote_hs.version >= SNAPPY_PROTOCOL_VERSION
          remote_hs
        end

        private
        def receiver_enc_handshake(receiver)
          auth_msg_binary, auth_packet = read_enc_handshake_msg(ENC_AUTH_MSG_LENGTH, receiver.private_key)
          auth_msg = AuthMsgV4.rlp_decode(auth_msg_binary)
          receiver.handle_auth_msg(auth_msg)

          auth_ack_msg = receiver.auth_ack_msg
          auth_ack_msg_plain_text = auth_ack_msg.rlp_encode!
          auth_ack_packet = if auth_msg.got_plain
                              raise NotImplementedError.new('not support pre eip8 plain text seal')
                            else
                              seal_eip8(auth_ack_msg_plain_text, receiver)
                            end
          @io.write(auth_ack_packet)

          receiver.extract_secrets(auth_packet, auth_ack_packet, initiator: false)
        end

        def initiator_enc_handshake(initiator)
          initiator_auth_msg = initiator.auth_msg
          auth_msg_plain_text = initiator_auth_msg.rlp_encode!
          # seal eip8
          auth_packet = seal_eip8(auth_msg_plain_text, initiator)
          @io.write(auth_packet)

          auth_ack_mgs_binary, auth_ack_packet = read_enc_handshake_msg(ENC_AUTH_RESP_MSG_LENGTH, initiator.private_key)
          auth_ack_msg = AuthRespV4.rlp_decode! auth_ack_mgs_binary
          initiator.handle_auth_ack_msg(auth_ack_msg)

          initiator.extract_secrets(auth_packet, auth_ack_packet, initiator: true)
        end

        def read_enc_handshake_msg(plain_size, private_key)
          packet = @io.read(plain_size)

          decrypt_binary_msg = begin
            private_key.ecies_decrypt(packet)
          rescue Crypto::ECIESDecryptionError => e
            nil
          end

          # pre eip old plain format
          return decrypt_binary_msg if decrypt_binary_msg

          # try decode eip8 format
          prefix = packet[0...2]
          size = ETH::Utils.big_endian_decode(prefix)
          raise FormatError.new("EIP8 format message size #{size} less than plain_size #{plain_size}") if size < plain_size

          # continue read remain bytes
          packet << @io.read(size - plain_size + 2)
          # decrypt message
          [private_key.ecies_decrypt(packet[2..-1], prefix), packet]
        end

        def read_protocol_handshake
          msg = @frame_io.read_msg

          if msg.size > BASE_PROTOCOL_MAX_MSG_SIZE
            raise MessageOverflowError.new("message size #{msg.size} is too big")
          end
          if msg.code == MESSAGES[:discovery]
            payload = RLP.decode(msg.payload)
            raise UnexpectedMessageError.new("expected handshake, get discovery, reason: #{payload}")
          end
          if msg.code != MESSAGES[:handshake]
            raise UnexpectedMessageError.new("expected handshake, get #{msg.code}")
          end
          ProtocolHandshake.rlp_decode!(msg.payload)
        end

        def set_timeout(io)
          timeout = HANDSHAKE_TIMEOUT

          if io.is_a?(BasicSocket)
            secs = Integer(timeout)
            usecs = Integer((timeout - secs) * 1_000_000)
            optval = [secs, usecs].pack("l_2")
            io.setsockopt Socket::SOL_SOCKET, Socket::SO_RCVTIMEO, optval
            io.setsockopt Socket::SOL_SOCKET, Socket::SO_SNDTIMEO, optval
          end
        end

        def seal_eip8(encoded_msg, handshake)
          # padding encoded message, make message distinguished from pre eip8
          encoded_msg += "\x00".b * rand(100..300)
          prefix = encoded_prefix(encoded_msg.size + ECIES_OVERHEAD)

          enc = handshake.remote_key.ecies_encrypt(encoded_msg, prefix)
          prefix + enc
        end

        # encode 16 uint prefix
        def encoded_prefix(n)
          prefix = Utils.big_endian_encode(n)
          # pad to 2 bytes
          prefix.ljust(2, "\x00".b)
        end
      end

    end
  end
end