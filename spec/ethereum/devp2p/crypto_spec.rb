require 'ethereum/devp2p/crypto'

RSpec.describe Ethereum::Devp2p::Crypto do
  it 'self consistent' do
    key = OpenSSL::PKey::EC.new('secp256k1')
    key.generate_key
    message = 'We are all in the gutter, but some of us are looking at the stars.'
    encrypt_data = Ethereum::Devp2p::Crypto.ecies_encrypt(message, key)
    text = Ethereum::Devp2p::Crypto.ecies_decrypt(encrypt_data, key)
    expect(text).to eq message
  end
end
