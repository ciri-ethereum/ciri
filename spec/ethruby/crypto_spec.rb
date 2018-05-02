require 'ethruby/crypto'

RSpec.describe Eth::Crypto do
  it 'self consistent' do
    key = OpenSSL::PKey::EC.new('secp256k1')
    key.generate_key
    message = 'We are all in the gutter, but some of us are looking at the stars.'
    encrypt_data = Eth::Crypto.ecies_encrypt(message, key)
    text = Eth::Crypto.ecies_decrypt(encrypt_data, key)
    expect(text).to eq message
  end
end
