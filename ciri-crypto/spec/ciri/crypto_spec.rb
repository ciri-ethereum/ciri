# frozen_string_literal: true

# Copyright 2018 Jiang Jinyang <https://justjjy.com>, classicalliu
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



# require 'spec_helper'
require 'openssl'
require 'ciri/crypto'

RSpec.describe Ciri::Crypto do
  it 'self consistent' do
    key = OpenSSL::PKey::EC.new('secp256k1')
    key.generate_key
    message = 'We are all in the gutter, but some of us are looking at the stars.'
    encrypt_data = Ciri::Crypto.ecies_encrypt(message, key)
    text = Ciri::Crypto.ecies_decrypt(encrypt_data, key)
    expect(text).to eq message
  end

  context 'ecdsa recover' do
    it 'self consistent' do
      ec_key = OpenSSL::PKey::EC.new('secp256k1')
      ec_key.generate_key

      msg = Ciri::Utils.keccak "hello world"

      privkey = ec_key.private_key.to_s(2)
      signature = Ciri::Crypto.ecdsa_signature(privkey, msg)

      raw_pubkey = Ciri::Crypto.ecdsa_recover(msg, signature, return_raw_key: true)

      expect(raw_pubkey).to eq ec_key.public_key.to_bn.to_s(2)
    end

    it 'pass geth recovery test case' do
      msg = ["ce0677bb30baa8cf067c88db9811f4333d131bf8bcf12fe7065d211dce971008"].pack("H*")
      signature = ["90f27b8b488db00b00606796d2987f6a5f59ae62ea05effe84fef5b8b0e549984a691139ad57a3f0b906637673aa2f63d1f55cb1a69199d4009eea23ceaddc9301"].pack("H*")
      pubkey = ["04e32df42865e97135acfb65f3bae71bdc86f4d49150ad6a440b6f15878109880a0a2b2667f7e725ceea70c673093bf67663e0312623c8e091b13cf2c0f11ef652"].pack("H*")
      raw_key = Ciri::Crypto.ecdsa_recover(msg, signature)
      expect(raw_key).to eq pubkey
    end
  end
end
