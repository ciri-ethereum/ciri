# frozen_string_literal: true

# Copyright (c) 2018, by Jiang Jinyang. <https://justjjy.com>
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


require 'socket'
require 'ciri/devp2p/rlpx/connection'
require 'ciri/devp2p/rlpx/protocol_handshake'

RSpec.describe Ciri::DevP2P::RLPX::Connection do

  it 'handshake' do

    pk1 = Ciri::Key.random
    pk2 = Ciri::Key.random

    s1, s2 = UNIXSocket.pair

    initiator_node_id = Ciri::DevP2P::RLPX::NodeID.new pk1
    receive_node_id = Ciri::DevP2P::RLPX::NodeID.new pk2

    initiator = Ciri::DevP2P::RLPX::Connection.new(s1)
    receiver = Ciri::DevP2P::RLPX::Connection.new(s2)

    initiator_protocol_handshake = Ciri::DevP2P::RLPX::ProtocolHandshake.new(
      version: 1,
      name: "initiator",
      caps: [Ciri::DevP2P::RLPX::Cap.new(name: 'hello', version: 1)],
      listen_port: 33333,
      id: "ciri-initiator")
    receiver_protocol_handshake = Ciri::DevP2P::RLPX::ProtocolHandshake.new(
      version: 1,
      name: "receiver",
      caps: [Ciri::DevP2P::RLPX::Cap.new(name: 'nihao', version: 2)],
      listen_port: 22222,
      id: "ciri-receiver")

    # start initiator handshakes
    thr = Thread.new {
      initiator.encryption_handshake!(private_key: pk1, node_id: receive_node_id)
      initiator.protocol_handshake!(initiator_protocol_handshake)
    }

    receiver.encryption_handshake!(private_key: pk2)
    # receiver get initiator_protocol_hanshake
    expect(receiver.protocol_handshake!(receiver_protocol_handshake)).to eq initiator_protocol_handshake
    # initiator get receiver_protocol_hanshake
    expect(thr.value).to eq receiver_protocol_handshake
  end
end