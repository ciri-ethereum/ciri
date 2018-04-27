require 'reth/devp2p/crypto'

RSpec.describe Reth::Devp2p::Crypto do
  it 'self consistent' do
    key = OpenSSL::PKey::EC.new('secp256k1')
    key.generate_key
    message = 'We are all in the gutter, but some of us are looking at the stars.'
    encrypt_data = Reth::Devp2p::Crypto.ecies_encrypt(message, key)
    text = Reth::Devp2p::Crypto.ecies_decrypt(encrypt_data, key)
    expect(text).to eq message
  end
end
