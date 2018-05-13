require 'ethruby/rlp'
require 'ethruby/rlp/serializable'

RSpec.describe ETH::RLP::Serializable do

  let(:my_class) {
    Class.new do
      include ETH::RLP::Serializable

      schema [
               :signature,
               {nonce: [:int]},
               {version: :int}
             ]
      default_data(version: 1)
    end
  }

  it 'apply default value' do
    msg = my_class.new(signature: '123', nonce: [1, 2, 3], version: 4)
    expect(msg.version).to eq 4
    msg = my_class.new(signature: '123', nonce: [1, 2, 3])
    expect(msg.version).to eq 1
  end

  it 'raise invalid if missing key' do
    expect do
      my_class.new(signature: '123')
    end.to raise_error(ETH::RLP::Serializable::Schema::InvalidSchemaError)
  end

  it 'rlp encoding/decoding' do
    msg = my_class.new(signature: '123', nonce: [1, 2, 3], version: 4)
    binary = msg.rlp_encode!
    # is valid RLP encoding format
    expect {ETH::RLP.decode(binary)}.to_not raise_error

    decoded_msg = my_class.rlp_decode!(binary)
    expect(decoded_msg).to eq msg
  end

  context 'deserialize real world geth handshake' do
    it 'decode handshake' do
      my_cap = Class.new do
        include ETH::RLP::Serializable

        schema [
                 :name,
                 {version: :int}
               ]
      end

      my_protocol_handshake = Class.new do
        include ETH::RLP::Serializable

        schema [
                 {version: :int},
                 :name,
                 {caps: [my_cap]},
                 {listen_port: :int},
                 :id
               ]
      end

      encoded_handshake = ['f87d05b1476574682f76312e382e372d756e737461626c652d38366265393162332f64617277696e2d616d6436342f676f312e3130c6c5836574683f80b840da982df3c882252c126ac3ee8fa008ade932c4166dfdc7c117c9852b5df0c6ddcf34bf2555a38596268b3b6bcbdaf48bba57b84a1abc400b4ba65c59ee5342c3'].pack("H*")
      hs = my_protocol_handshake.rlp_decode(encoded_handshake)
      expect(hs.version).to eq 5
      expect(hs.listen_port).to eq 0
      expect(hs.caps[0].name).to eq 'eth'
    end
  end

end
