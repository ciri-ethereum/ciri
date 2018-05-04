# frozen_string_literal: true

require 'ethruby/crypto'
require 'ethruby/key'

RSpec.describe Eth::Crypto do
  it 'self consistent' do
    key = OpenSSL::PKey::EC.new('secp256k1')
    key.generate_key
    message = 'We are all in the gutter, but some of us are looking at the stars.'
    encrypt_data = Eth::Crypto.ecies_encrypt(message, key)
    text = Eth::Crypto.ecies_decrypt(encrypt_data, key)
    expect(text).to eq message
  end

  context 'ecdsa recover' do
    it 'self consistent' do
      key = Eth::Key.random
      msg = Eth::Utils.sha3 "hello world"
      signature = key.ecdsa_signature(msg)
      expect(Eth::Key.ecdsa_recover(msg, signature).raw_public_key).to eq key.raw_public_key
    end

    it 'pass geth recovery test case' do
      msg = ["ce0677bb30baa8cf067c88db9811f4333d131bf8bcf12fe7065d211dce971008"].pack("H*")
      signature = ["90f27b8b488db00b00606796d2987f6a5f59ae62ea05effe84fef5b8b0e549984a691139ad57a3f0b906637673aa2f63d1f55cb1a69199d4009eea23ceaddc9301"].pack("H*")
      pubkey = ["04e32df42865e97135acfb65f3bae71bdc86f4d49150ad6a440b6f15878109880a0a2b2667f7e725ceea70c673093bf67663e0312623c8e091b13cf2c0f11ef652"].pack("H*")
      raw_key = Eth::Crypto.ecdsa_recover(msg, signature)
      expect(raw_key).to eq pubkey
    end
  end
end
