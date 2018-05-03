require 'ethruby/rlp/serializable'

my_class = Class.new do
  include Eth::RLP::Serializable

  schema [
           :signature,
           {nonce: [:int]},
           {version: :int}
         ]
  default_data(version: 1)
end

RSpec.describe Eth::RLP::Serializable do
  it 'apply default value' do
    msg = my_class.new(signature: '123', nonce: [1, 2, 3], version: 4)
    expect(msg.version).to eq 4
    msg = my_class.new(signature: '123', nonce: [1, 2, 3])
    expect(msg.version).to eq 1
  end

  it 'raise invalid if missing key' do
    expect do
      my_class.new(signature: '123')
    end.to raise_error(Eth::RLP::Serializable::Schema::InvalidSchemaError)
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
