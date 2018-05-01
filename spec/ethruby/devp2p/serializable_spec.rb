require 'ethruby/devp2p/serializable'

my_class = Class.new do
  include Eth::DevP2P::Serializable

  schema [
           {got_plain: :bool},
           :signature,
           {nonce: [:int]},
           {version: :int}
         ]
  default_data(got_plain: false)
end

RSpec.describe Eth::DevP2P::Serializable do
  it 'apply default value' do
    msg = my_class.new(signature: '123', nonce: [1, 2, 3], version: 4)
    expect(msg.got_plain).to be_falsey
  end

  it 'raise invalid if missing key' do
    expect do
      my_class.new(signature: '123', nonce: [1, 2, 3])
    end.to raise_error(Eth::DevP2P::Serializable::Schema::InvalidSchemaError)
  end

  it 'rlp encoding/decoding' do
    msg = my_class.new(signature: '123', nonce: [1, 2, 3], version: 4)
    binary = msg.rlp_encode!
    # is valid RLP encoding format
    expect {Eth::RLP.decode(binary)}.to_not raise_error

    decoded_msg = my_class.rlp_decode!(binary)
    expect(decoded_msg).to eq msg
  end
end
