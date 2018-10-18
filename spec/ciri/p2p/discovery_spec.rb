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


require 'spec_helper'
require 'ciri/p2p/discovery'
require 'ciri/rlp'

RSpec.describe Ciri::P2P::Discovery do
  context 'dicovery message' do
    let(:key){Ciri::Key.random}
    let(:ping) do
      Ciri::P2P::Discovery::Ping.new(
        version: 1,
        from: Ciri::P2P::Discovery::From.new(sender_ip: IPAddr.new('127.0.0.1').to_i, sender_udp_port: 30303, sender_tcp_port: 30303),
        to: Ciri::P2P::Discovery::To.new(recipient_ip: IPAddr.new('192.168.1.3').to_i, recipient_udp_port: 30303),
        expiration: Time.now.to_i + 3600
      )
    end

    it '#validate' do
      key = Ciri::Key.random
      msg = Ciri::Utils.keccak "hello world"
      signature = key.ecdsa_signature(msg)
      expect(Ciri::Key.ecdsa_recover(msg, signature).raw_public_key).to eq key.raw_public_key
    end

    it 'decode and encode message' do
      msg = Ciri::P2P::Discovery::Message.pack(ping, private_key: key)
      encoded = msg.encode_message
      msg2 = Ciri::P2P::Discovery::Message.decode_message(encoded)
      expect(msg.message_hash).to eq msg2.message_hash
      expect(msg.sender.to_s).to eq msg2.sender.to_s
      expect(msg.sender.to_bytes).to eq Ciri::P2P::NodeID.new(key).to_bytes
      expect(msg.packet).to eq msg2.packet
    end

    let(:too_big_msg) do
      Class.new do
        include Ciri::RLP::Serializable
        schema(
          data: Ciri::RLP::Bytes
        )

        def self.code
          0x00
        end
      end.new(data: "0x00".b * 1280)
    end

    it '#pack' do
      expect do
        Ciri::P2P::Discovery::Message.pack(ping, private_key: key)
      end.not_to raise_error

      expect do
        Ciri::P2P::Discovery::Message.pack(too_big_msg, private_key: key)
      end.to raise_error(Ciri::P2P::InvalidMessageError)
    end
  end
end

