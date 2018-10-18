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


require 'ciri/p2p/rlpx'
require 'ciri/key'

RSpec.describe Ciri::P2P::RLPX::EncryptionHandshake do
  it 'do handshake' do
    pk1 = Ciri::Key.random
    pk2 = Ciri::Key.random

    initiator_node_id = Ciri::P2P::NodeID.new pk1
    receive_node_id = Ciri::P2P::NodeID.new pk2

    initiator = Ciri::P2P::RLPX::EncryptionHandshake.new(private_key: pk1, remote_id: receive_node_id)
    receiver = Ciri::P2P::RLPX::EncryptionHandshake.new(private_key: pk2, remote_id: initiator_node_id)

    # initiator send auth-msg
    initiator_auth_msg = initiator.auth_msg
    auth_packet = initiator_auth_msg.rlp_encode
    auth_msg = Ciri::P2P::RLPX::AuthMsgV4.rlp_decode(auth_packet)

    # check serialize/deserialize
    expect(auth_msg).to eq initiator_auth_msg

    # receiver handle auth-msg, get remote random_pubkey nonce_bytes
    receiver.handle_auth_msg(auth_msg)
    expect(receiver.remote_random_key.raw_public_key).to eq initiator.random_key.raw_public_key
    expect(receiver.initiator_nonce).to eq initiator.initiator_nonce

    # receiver send auth-ack
    auth_ack_msg = receiver.auth_ack_msg
    auth_ack_packet = auth_ack_msg.rlp_encode
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
