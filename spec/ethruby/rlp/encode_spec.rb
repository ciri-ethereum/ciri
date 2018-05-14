require 'ethruby/rlp'

RSpec.describe ETH::RLP::Encode do

  context 'numbers' do
    it '0x00' do
      expect(ETH::RLP.encode("\x00")).to eq "\x00"
    end

    it '0x0f' do
      expect(ETH::RLP.encode("\x0f")).to eq "\x0f"
    end

    it '1024' do
      expect(ETH::RLP.encode("\x04\x00")).to eq "\x82\x04\x00".b
    end
  end

  context 'encode strings' do
    it 'single byte' do
      expect(ETH::RLP.encode('a')).to eq 'a'.b
    end

    it 'simple string' do
      expect(ETH::RLP.encode('dog')).to eq "\x83dog".b
    end

    it 'empty' do
      expect(ETH::RLP.encode('')).to eq "\x80".b
    end

    it 'long string' do
      expect(ETH::RLP.encode('Lorem ipsum dolor sit amet, consectetur adipisicing elit')).to eq "\xb8\x38Lorem ipsum dolor sit amet, consectetur adipisicing elit".b
    end
  end

  context 'encode lists' do
    it 'list of strings' do
      expect(ETH::RLP.encode(["cat", "dog"])).to eq "\xc8\x83cat\x83dog".b
    end

    it 'empty list' do
      expect(ETH::RLP.encode([])).to eq "\xc0".b
    end

    it "empty lists" do
      expect(ETH::RLP.encode([[], [[]], [[], [[]]]])).to eq "\xc7\xc0\xc1\xc0\xc3\xc0\xc1\xc0".b
    end
  end

  context 'encode int' do
    it '0' do
      expect(ETH::RLP.encode_with_type(0, Integer)).to eq "\x80".b
    end

    it '127' do
      expect(ETH::RLP.encode_with_type(127, Integer)).to eq "\x7f".b
    end

    it '128' do
      expect(ETH::RLP.encode_with_type(128, Integer)).to eq "\x81\x80".b
    end

    it '1024' do
      expect(ETH::RLP.encode_with_type(1024, Integer)).to eq "\x82\x04\x00".b
    end
  end
end
