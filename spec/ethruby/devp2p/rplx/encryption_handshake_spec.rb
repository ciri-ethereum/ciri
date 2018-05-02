# frozen_string_literal: true

require 'ethruby/devp2p/rlpx'
require 'ethruby/key'

RSpec.describe Eth::DevP2P::RLPX::EncryptionHandshake do
  it 'do handshake' do
    pk1 = Eth::Key.random
    pk2 = Eth::Key.random

    initiator_node_id = Eth::DevP2P::RLPX::NodeID.new pk1
    receive_node_id = Eth::DevP2P::RLPX::NodeID.new pk2

    initiator = Eth::DevP2P::RLPX::EncryptionHandshake.new(private_key: pk1, remote_id: receive_node_id)
    receiver = Eth::DevP2P::RLPX::EncryptionHandshake.new(private_key: pk2, remote_id: initiator_node_id)

    # initiator send auth-msg
    initiator_auth_msg = initiator.auth_msg
    binary_auth_msg = initiator_auth_msg.rlp_encode!
    auth_msg = Eth::DevP2P::RLPX::AuthMsgV4.rlp_decode(binary_auth_msg)

    # check serialize/deserialize
    expect(auth_msg).to eq initiator_auth_msg

    # receiver handle auth-msg, get remote random_pubkey nonce_bytes
    receiver.handle_auth_msg(auth_msg)
    expect(receiver.remote_random_key.raw_public_key).to eq initiator.random_key.raw_public_key
    expect(receiver.remote_nonce_bytes).to eq initiator.nonce_bytes

    # receiver send auth-ack
    auth_ack_msg = receiver.auth_ack_msg
    initiator.handle_auth_ack_msg(auth_ack_msg)
    expect(initiator.remote_random_key.raw_public_key).to eq receiver.random_key.raw_public_key
    expect(initiator.remote_nonce_bytes).to eq receiver.nonce_bytes

    #initiator derives secrets
    initiator_secrets = initiator.extract_secrets
    receiver_secrets = receiver.extract_secrets
    expect(initiator_secrets.remote_id).to eq receive_node_id
    expect(receiver_secrets.remote_id).to eq initiator_node_id
  end
end
