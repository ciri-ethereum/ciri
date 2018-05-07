# frozen_string_literal: true

require 'socket'
require 'ethruby/devp2p/rlpx/connection'
require 'ethruby/devp2p/rlpx/protocol_handshake'

RSpec.describe ETH::DevP2P::RLPX::Connection do

  it 'handshake' do

    pk1 = ETH::Key.random
    pk2 = ETH::Key.random

    s1, s2 = UNIXSocket.pair

    initiator_node_id = ETH::DevP2P::RLPX::NodeID.new pk1
    receive_node_id = ETH::DevP2P::RLPX::NodeID.new pk2

    initiator = ETH::DevP2P::RLPX::Connection.new(s1)
    receiver = ETH::DevP2P::RLPX::Connection.new(s2)

    initiator_protocol_handshake = ETH::DevP2P::RLPX::ProtocolHandshake.new(
      version: 1,
      name: "initiator",
      caps: [ETH::DevP2P::RLPX::Cap.new(name: 'hello', version: 1)],
      listen_port: 33333,
      id: "ethruby-initiator")
    receiver_protocol_handshake = ETH::DevP2P::RLPX::ProtocolHandshake.new(
      version: 1,
      name: "receiver",
      caps: [ETH::DevP2P::RLPX::Cap.new(name: 'nihao', version: 2)],
      listen_port: 22222,
      id: "ethruby-receiver")

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