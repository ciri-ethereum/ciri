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
require 'async'
require 'ciri/p2p/peer'
require 'ciri/p2p/protocol'
require 'ciri/p2p/rlpx/protocol_handshake'
require 'concurrent'

RSpec.describe Ciri::P2P::Peer do
  let(:eth_protocol) {Ciri::P2P::Protocol.new(name: 'eth', version: 63, length: 17)}
  let(:old_eth_protocol) {Ciri::P2P::Protocol.new(name: 'eth', version: 62, length: 8)}
  let(:hello_protocol) {Ciri::P2P::Protocol.new(name: 'hello', version: 1, length: 16)}
  let(:caps) {[
    Ciri::P2P::RLPX::Cap.new(name: 'eth', version: 63),
    Ciri::P2P::RLPX::Cap.new(name: 'eth', version: 62),
    Ciri::P2P::RLPX::Cap.new(name: 'hello', version: 1),
  ]}
  let(:handshake){Ciri::P2P::RLPX::ProtocolHandshake.new(version: 4, name: 'test', caps: caps, id: 0)}
  let(:protocols){[
    eth_protocol,
    old_eth_protocol,
    hello_protocol
  ]}

  it 'find_protocol_io_by_msg_code' do
    IO.pipe do |io, io2|
      peer = Ciri::P2P::Peer.new(io, handshake, protocols)
      base_offset = Ciri::P2P::RLPX::BASE_PROTOCOL_LENGTH

      # According to the offset of DEVP2P message code,
      # we should fetch ETH protocl first which offset range is 1...17
      (1...17).each do |raw_code|
        expect(peer.find_protocol_io_by_msg_code(raw_code + base_offset).protocol).to eq eth_protocol
      end
      # the hello protocol offset range is 17...17 + 16
      (17...17 + 16).each do |raw_code|
        expect(peer.find_protocol_io_by_msg_code(raw_code + base_offset).protocol).to eq hello_protocol
      end
    end
  end

  it 'disconnect a peer' do
    IO.pipe do |io, io2|
      peer = Ciri::P2P::Peer.new(io, handshake, protocols)
      expect(peer.disconnected?).to be_falsey
      peer.disconnect
      expect(peer.disconnected?).to be_truthy
    end
  end

end

