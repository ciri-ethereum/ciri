# frozen_string_literal: true

require 'ethruby/devp2p/rlpx'
require 'ethruby/key'

RSpec.describe ETH::DevP2P::RLPX::EncryptionHandshake do
  it 'do handshake' do
    pk1 = ETH::Key.random
    pk2 = ETH::Key.random

    initiator_node_id = ETH::DevP2P::RLPX::NodeID.new pk1
    receive_node_id = ETH::DevP2P::RLPX::NodeID.new pk2

    initiator = ETH::DevP2P::RLPX::EncryptionHandshake.new(private_key: pk1, remote_id: receive_node_id)
    receiver = ETH::DevP2P::RLPX::EncryptionHandshake.new(private_key: pk2, remote_id: initiator_node_id)

    # initiator send auth-msg
    initiator_auth_msg = initiator.auth_msg
    auth_packet = initiator_auth_msg.rlp_encode!
    auth_msg = ETH::DevP2P::RLPX::AuthMsgV4.rlp_decode(auth_packet)

    # check serialize/deserialize
    expect(auth_msg).to eq initiator_auth_msg

    # receiver handle auth-msg, get remote random_pubkey nonce_bytes
    receiver.handle_auth_msg(auth_msg)
    expect(receiver.remote_random_key.raw_public_key).to eq initiator.random_key.raw_public_key
    expect(receiver.initiator_nonce).to eq initiator.initiator_nonce

    # receiver send auth-ack
    auth_ack_msg = receiver.auth_ack_msg
    auth_ack_packet = auth_ack_msg.rlp_encode!
    initiator.handle_auth_ack_msg(auth_ack_msg)
    expect(initiator.remote_random_key.raw_public_key).to eq receiver.random_key.raw_public_key
    expect(initiator.receiver_nonce).to eq receiver.receiver_nonce

    #initiator derives secrets
    initiator_secrets = initiator.extract_secrets(auth_packet, auth_ack_packet, initiator: true)
    receiver_secrets = receiver.extract_secrets(auth_packet, auth_ack_packet, initiator: false)
    expect(initiator_secrets.remote_id).to eq receive_node_id
    expect(receiver_secrets.remote_id).to eq initiator_node_id
  end
end
