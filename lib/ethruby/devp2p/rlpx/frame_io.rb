# frozen_string_literal: true

require 'stringio'
require 'ethruby/rlp/serializable'
require_relative 'error'

module ETH
  module DevP2P
    module RLPX

      # RLPX message
      class Message
        include ETH::RLP::Serializable

        schema [
                 {code: :int},
                 {size: :int},
                 :payload,
                 :received_at
               ]
        default_data(received_at: nil)
      end

      class FrameIO

        # max message size, took 3 byte to store message size, equal to uint24 max size
        MAX_MESSAGE_SIZE = (1 << 24) - 1

        class Error < RLPX::Error
        end

        class OverflowError < Error
        end

        class InvalidError < Error
        end

        def initialize(io, secrets)
          @io = io
          @secrets = secrets

          mac_aes_version = secrets.mac.size * 8
          @mac = OpenSSL::Cipher.new("AES#{mac_aes_version}")
          @mac.encrypt
          @mac.key = secrets.mac

          # init encrypt/decrypt
          aes_version = secrets.aes.size * 8
          @encrypt = OpenSSL::Cipher::AES.new(aes_version, :CTR)
          @decrypt = OpenSSL::Cipher::AES.new(aes_version, :CTR)
          zero_iv = "\x00".b * @encrypt.iv_len
          @encrypt.iv = zero_iv
          @encrypt.key = secrets.aes
          @decrypt.iv = zero_iv
          @decrypt.key = secrets.aes
        end

        def send_data(code, data)
          msg = Message.new(code: code, size: data.size, payload: data)
          write_msg(msg)
        end

        def write_msg(msg)
          pkg_type = RLP.encode_with_type msg.code, :int, zero: "\x00"

          # write header
          head_buf = "\x00".b * 32

          frame_size = pkg_type.size + msg.size
          if frame_size > MAX_MESSAGE_SIZE
            raise OverflowError.new("Message size is overflow, frame size: #{frame_size}")
          end

          write_frame_size(head_buf, frame_size)

          # Can't find related RFC or RLPX Spec, below code is copy from geth
          # write zero header, but I can't find spec or explanations of 'zero header'
          head_buf[3..5] = [0xC2, 0x80, 0x80].pack('c*')
          # encrypt first half
          head_buf[0...16] = @encrypt.update(head_buf[0...16]) + @encrypt.final
          # write header mac
          head_buf[16...32] = update_mac(@secrets.egress_mac, head_buf[0...16])
          @io.write head_buf
          # write encrypt frame
          write_frame(pkg_type)
          write_frame(msg.payload)
          # pad to n*16 bytes
          if (need_padding = frame_size % 16) > 0
            write_frame("\x00".b * (16 - need_padding))
          end
          finish_write_frame
        end

        def read_msg
          # verify header mac
          head_buf = read(32)
          verify_mac = update_mac(@secrets.ingress_mac, head_buf[0...16])
          unless ETH::Utils.secret_compare(verify_mac, head_buf[16...32])
            raise InvalidError.new('bad header mac')
          end

          # decrypt header
          head_buf[0...16] = @decrypt.update(head_buf[0...16]) + @decrypt.final

          # read frame
          frame_size = read_frame_size head_buf
          # frame size should padded to n*16 bytes
          need_padding = frame_size % 16
          padded_frame_size = need_padding > 0 ? frame_size + (16 - need_padding) : frame_size
          frame_buf = read(padded_frame_size)

          # verify frame mac
          @secrets.ingress_mac.update(frame_buf)
          frame_digest = @secrets.ingress_mac.digest
          verify_mac = update_mac(@secrets.ingress_mac, frame_digest)
          # clear head_buf 16...32 bytes(header mac), since we will not need it
          frame_mac = head_buf[16...32] = read(16)
          unless ETH::Utils.secret_compare(verify_mac, frame_mac)
            raise InvalidError.new('bad frame mac')
          end

          # decrypt frame
          frame_content = @decrypt.update(frame_buf) + @decrypt.final
          frame_content = frame_content[0...frame_size]
          msg_code = RLP.decode_with_type frame_content[0], :int
          Message.new(code: msg_code, size: frame_content.size - 1, payload: frame_content[1..-1])
        end

        private
        def read(length)
          if (buf = @io.read(length)).nil?
            @io.close
            raise EOFError.new('read EOF, connection closed')
          end
          buf
        end

        def write_frame_size(buf, frame_size)
          # frame-size: 3-byte integer size of frame, big endian encoded (excludes padding)
          bytes_of_frame_size = [
            frame_size >> 16,
            frame_size >> 8,
            frame_size % 256
          ]
          buf[0..2] = bytes_of_frame_size.pack('c*')
        end

        def read_frame_size(buf)
          size_bytes = buf[0..2].each_byte.map(&:ord)
          (size_bytes[0] << 16) + (size_bytes[1] << 8) + (size_bytes[2])
        end

        def update_mac(mac, seed)
          # reset mac each time
          @mac.reset
          aes_buf = (@mac.update(mac.digest) + @mac.final)[0...@mac.block_size]
          aes_buf = aes_buf.each_byte.with_index.map {|b, i| b ^ seed[i].ord}.pack('c*')
          mac.update(aes_buf)
          # return first 16 byte
          mac.digest[0...16]
        end

        # write encrypt content to @io, and update @secrets.egress_mac
        def write_frame(string_or_io)
          if string_or_io.is_a?(IO)
            while (s = string_or_io.read(4096))
              write_frame_string(s)
            end
          else
            write_frame_string(string_or_io)
          end
        end

        def write_frame_string(s)
          encrypt_content = @encrypt.update(s) + @encrypt.final
          # update egress_mac
          @secrets.egress_mac.update encrypt_content
          @io.write encrypt_content
        end

        def finish_write_frame
          # get frame digest
          frame_digest = @secrets.egress_mac.digest
          @io.write update_mac(@secrets.egress_mac, frame_digest)
        end
      end

    end
  end
end