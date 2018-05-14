require 'ethruby/rlp'

RSpec.describe ETH::RLP::Decode do

  context 'numbers' do
    it '0x00' do
      expect(ETH::RLP.decode("\x00".b)).to eq "\x00"
    end

    it '0x0f' do
      expect(ETH::RLP.decode("\x0f".b)).to eq "\x0f"
    end

    it '1024' do
      expect(ETH::RLP.decode("\x82\x04\x00".b)).to eq "\x04\x00"
    end
  end

  context 'decode strings' do
    it 'single byte' do
      expect(ETH::RLP.decode('a'.b)).to eq 'a'
    end

    it 'simple string' do
      expect(ETH::RLP.decode("\x83dog")).to eq 'dog'.b
    end

    it 'empty' do
      expect(ETH::RLP.decode("\x80")).to eq ''
    end

    it 'long string' do
      expect(ETH::RLP.decode("\xb8\x38Lorem ipsum dolor sit amet, consectetur adipisicing elit".b)).to eq 'Lorem ipsum dolor sit amet, consectetur adipisicing elit'
    end
  end

  context 'decode lists' do
    it 'list of strings' do
      expect(ETH::RLP.decode("\xc8\x83cat\x83dog".b)).to eq ["cat", "dog"]
    end

    it 'empty list' do
      expect(ETH::RLP.decode("\xc0")).to eq []
    end

    it "empty lists" do
      expect(ETH::RLP.decode("\xc7\xc0\xc1\xc0\xc3\xc0\xc1\xc0")).to eq [[], [[]], [[], [[]]]]
    end
  end

  context 'decode int' do
    it '0' do
      expect(ETH::RLP.decode_with_type("\x80".b, Integer)).to eq 0
    end

    it '127' do
      expect(ETH::RLP.decode_with_type("\x7f".b, Integer)).to eq 127
    end

    it '128' do
      expect(ETH::RLP.decode_with_type("\x81\x80".b, Integer)).to eq 128
    end

    it '1024' do
      expect(ETH::RLP.decode_with_type("\x82\x04\x00".b, Integer)).to eq 1024
    end
  end
end