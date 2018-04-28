require 'ethruby/devp2p/crypto'

RSpec.describe Eth::DevP2P::Crypto do
  it 'self consistent' do
    key = OpenSSL::PKey::EC.new('secp256k1')
    key.generate_key
    message = 'We are all in the gutter, but some of us are looking at the stars.'
    encrypt_data = Eth::DevP2P::Crypto.ecies_encrypt(message, key)
    text = Eth::DevP2P::Crypto.ecies_decrypt(encrypt_data, key)
    expect(text).to eq message
  end
end
