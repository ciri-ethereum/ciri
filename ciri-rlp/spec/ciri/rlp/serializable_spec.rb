# Copyright 2018 Jiang Jinyang <https://justjjy.com>
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


require 'ciri/rlp'
require 'ciri/rlp/serializable'

RSpec.describe Ciri::RLP::Serializable do

  let(:my_class) {
    Class.new do
      include Ciri::RLP::Serializable

      schema [
               :signature,
               {nonce: [Integer]},
               {version: Integer}
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
    end.to raise_error(Ciri::RLP::Serializable::Schema::InvalidSchemaError)
  end

  it 'rlp encoding/decoding' do
    msg = my_class.new(signature: '123', nonce: [1, 2, 3], version: 4)
    binary = msg.rlp_encode
    # is valid RLP encoding format
    expect {Ciri::RLP.decode(binary)}.to_not raise_error

    decoded_msg = my_class.rlp_decode(binary)
    expect(decoded_msg).to eq msg
  end

  context 'deserialize real world geth handshake' do
    it 'decode handshake' do
      my_cap = Class.new do
        include Ciri::RLP::Serializable

        schema [
                 :name,
                 {version: Integer}
               ]
      end

      my_protocol_handshake = Class.new do
        include Ciri::RLP::Serializable

        schema [
                 {version: Integer},
                 :name,
                 {caps: [my_cap]},
                 {listen_port: Integer},
                 :id
               ]
      end

      encoded_handshake = ['f87d05b1476574682f76312e382e372d756e737461626c652d38366265393162332f64617277696e2d616d6436342f676f312e3130c6c5836574683f80b840da982df3c882252c126ac3ee8fa008ade932c4166dfdc7c117c9852b5df0c6ddcf34bf2555a38596268b3b6bcbdaf48bba57b84a1abc400b4ba65c59ee5342c3'].pack("H*")
      hs = my_protocol_handshake.rlp_decode(encoded_handshake)
      expect(hs.version).to eq 5
      expect(hs.listen_port).to eq 0
      expect(hs.caps[0].name).to eq 'eth'
    end

    it 'decode eth getBlockHashes' do
      get_block_hashes = Class.new do
        include Ciri::RLP::Serializable
        CODE = 0x03
        schema [
                 {hash_or_number: Integer},
                 {amount: Integer},
                 {skip: Integer},
                 {reverse: Ciri::RLP::Bool},
               ]
      end

      encoded_handshake = ['c7831d4c00018080'].pack("H*")
      msg = get_block_hashes.rlp_decode(encoded_handshake)
      expect(msg.hash_or_number).to eq 1920000
      expect(msg.amount).to eq 1
      expect(msg.skip).to eq 0
      expect(msg.reverse).to be_falsey
    end
  end

  context 'self consistent' do
    let(:raw_headers) {'f90213f90210a0e48ecfcb38189b103f389a719b782325bdf0f5c005871ea91cd11a52c30ac37ea01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d4934794829bd824b016326a401d083b33d092293333a830a07007e575a80584487653324053b8ef65cd843fd09d7805eec9d8b840ba60e202a0abf18050f443bdc29bff9a959cb48bdf060861b89662484010ecbb0fdd8d3d9da07129bfc1aefeff683decb5060a00e2d002a2e2934516092aa34d6d62bdb3406fb901000000000000000010000200000000020200002000000000000d100000000000000000000000000000000000000040000200000100000040d00000000000000400000000000802040000000008000000100000000000200000000002000000000000000004020000000000084000000800002000000080000000000114001800000000020000000000800002000000000000000000008008000002000000000100008000000000000000000000400000000000000000400000000000000000000000000002000000000000000000000000008000000012000420000000800020000100000080000000000000000000000000000000000000000000000001000000870683fbc9a3cbf9833ffa818366251183173f8284599d077c8fe4b883e5bda9e7a59ee4bb99e9b1bca0b9566fe1fe4ae4b237a54955b88cc990e64013d1bed4761b32fbd45742825d4488d50741500da57701'}
    let(:my_header) {
      Class.new do
        include Ciri::RLP::Serializable

        schema [
                 :parent_hash,
                 :ommers_hash,
                 :beneficiary,
                 :state_root,
                 :transactions_root,
                 :receipts_root,
                 :logs_bloom,
                 {difficulty: Integer},
                 {number: Integer},
                 {gas_limit: Integer},
                 {gas_used: Integer},
                 {timestamp: Integer},
                 :extra_data,
                 :mix_hash,
                 :nonce,
               ]
      end
    }

    it 'decode then encode again' do
      raw_headers_b = [raw_headers].pack("H*")
      headers = Ciri::RLP.decode(raw_headers_b, [my_header])
      expect(Ciri::RLP.encode(headers, [my_header]).unpack("H*")[0]).to eq raw_headers
    end
  end

end
