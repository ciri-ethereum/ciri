# frozen_string_literal: true

# Copyright 2018 Jiang Jinyang <https://justjjy.com>
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.


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