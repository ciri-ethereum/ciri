require 'ethruby/rlp'

RSpec.describe Eth::RLP::Encode do

  context 'numbers' do
    it '0x00' do
      expect(Eth::RLP.encode("\x00")).to eq "\x00"
    end

    it '0x0f' do
      expect(Eth::RLP.encode("\x0f")).to eq "\x0f"
    end

    it '1024' do
      expect(Eth::RLP.encode("\x04\x00")).to eq "\x82\x04\x00".b
    end
  end

  context 'encode strings' do
    it 'single byte' do
      expect(Eth::RLP.encode('a')).to eq 'a'.b
    end

    it 'simple string' do
      expect(Eth::RLP.encode('dog')).to eq "\x83dog".b
    end

    it 'empty' do
      expect(Eth::RLP.encode('')).to eq "\x80".b
    end

    it 'long string' do
      expect(Eth::RLP.encode('Lorem ipsum dolor sit amet, consectetur adipisicing elit')).to eq "\xb8\x38Lorem ipsum dolor sit amet, consectetur adipisicing elit".b
    end
  end

  context 'encode lists' do
    it 'list of strings' do
      expect(Eth::RLP.encode(["cat", "dog"])).to eq "\xc8\x83cat\x83dog".b
    end

    it 'empty list' do
      expect(Eth::RLP.encode([])).to eq "\xc0".b
    end

    it "empty lists" do
      expect(Eth::RLP.encode([[], [[]], [[], [[]]]])).to eq "\xc7\xc0\xc1\xc0\xc3\xc0\xc1\xc0".b
    end
  end
end