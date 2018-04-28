# frozen_string_literal: true

require 'ethruby/devp2p/rlpx'

RSpec.describe Eth::DevP2P::RLPX do
  context Eth::DevP2P::RLPX::HandShake do
    it 'do handshake' do
      pk1 = OpenSSL::PKey::EC.new('secp256k1')
      pk2 = OpenSSL::PKey::EC.new('secp256k1')
      pk1.generate_key
      pk2.generate_key

      initiator = Eth::DevP2P::RLPX::HandShake.new(private_key: pk1, remote_key: pk2)
      receiver = Eth::DevP2P::RLPX::HandShake.new(private_key: pk2, remote_key: pk1)

      # initiator send auth-msg
      initiator_auth_msg = initiator.auth_msg
      binary_auth_msg = initiator_auth_msg.rlp_encode!
      auth_msg = Eth::DevP2P::RLPX::AuthMsgV4.rlp_decode(binary_auth_msg)

      # check serialize/deserialize
      expect(auth_msg).to eq initiator_auth_msg

      # receiver handle auth-msg, get remote random_pubkey nonce_bytes
      receiver.handle_auth_msg(auth_msg)
      expect(receiver.remote_random_pubkey.serialize).to eq initiator.random_privkey.pubkey.serialize
      expect(receiver.remote_nonce_bytes).to eq initiator.nonce_bytes

      # receiver send auth-ack
      auth_ack_msg = receiver.auth_ack_msg
      initiator.handle_auth_ack_msg(auth_ack_msg)
      expect(initiator.remote_random_pubkey.serialize).to eq receiver.random_privkey.pubkey.serialize
      expect(initiator.remote_nonce_bytes).to eq receiver.nonce_bytes
      # optional: remote derives secrets and preemptively sends protocol-handshake (steps 9,11,8,10)
    end
  end
end
