require 'reth/rlp'

RSpec.describe Reth::RLP::Decode do

  context 'numbers' do
    it '0x00' do
      expect(Reth::RLP.decode("\x00".b)).to eq "\x00"
    end

    it '0x0f' do
      expect(Reth::RLP.decode("\x0f".b)).to eq "\x0f"
    end

    it '1024' do
      expect(Reth::RLP.decode("\x82\x04\x00".b)).to eq "\x04\x00"
    end
  end

  context 'decode strings' do
    it 'single byte' do
      expect(Reth::RLP.decode('a'.b)).to eq 'a'
    end

    it 'simple string' do
      expect(Reth::RLP.decode("\x83dog")).to eq 'dog'.b
    end

    it 'empty' do
      expect(Reth::RLP.decode("\x80")).to eq ''
    end

    it 'long string' do
      expect(Reth::RLP.decode("\xb8\x38Lorem ipsum dolor sit amet, consectetur adipisicing elit".b)).to eq 'Lorem ipsum dolor sit amet, consectetur adipisicing elit'
    end
  end

  context 'decode lists' do
    it 'list of strings' do
      expect(Reth::RLP.decode("\xc8\x83cat\x83dog".b)).to eq ["cat", "dog"]
    end

    it 'empty list' do
      expect(Reth::RLP.decode("\xc0")).to eq []
    end

    it "empty lists" do
      expect(Reth::RLP.decode("\xc7\xc0\xc1\xc0\xc3\xc0\xc1\xc0")).to eq [[], [[]], [[], [[]]]]
    end
  end
end