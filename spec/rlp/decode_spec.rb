require 'rlp/decode'

RSpec.describe RLP::Decode do

  context 'numbers' do
    it '0x00' do
      expect(RLP::Decode.decode("\x00".b)).to eq "\x00"
    end

    it '0x0f' do
      expect(RLP::Decode.decode("\x0f".b)).to eq "\x0f"
    end

    it '1024' do
      expect(RLP::Decode.decode("\x82\x04\x00".b)).to eq "\x04\x00"
    end
  end

  context 'decode strings' do
    it 'single byte' do
      expect(RLP::Decode.decode('a'.b)).to eq 'a'
    end

    it 'simple string' do
      expect(RLP::Decode.decode("\x83dog")).to eq 'dog'.b
    end

    it 'empty' do
      expect(RLP::Decode.decode("\x80")).to eq ''
    end

    it 'long string' do
      expect(RLP::Decode.decode("\xb8\x38Lorem ipsum dolor sit amet, consectetur adipisicing elit".b)).to eq 'Lorem ipsum dolor sit amet, consectetur adipisicing elit'
    end
  end

  context 'decode lists' do
    it 'list of strings' do
      expect(RLP::Decode.decode("\xc8\x83cat\x83dog".b)).to eq ["cat", "dog"]
    end

    it 'empty list' do
      expect(RLP::Decode.decode("\xc0")).to eq []
    end

    it "empty lists" do
      expect(RLP::Decode.decode("\xc7\xc0\xc1\xc0\xc3\xc0\xc1\xc0")).to eq [[], [[]], [[], [[]]]]
    end
  end
end