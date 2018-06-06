# frozen_string_literal: true

# Copyright (c) 2018, by Jiang Jinyang. <https://justjjy.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


require 'spec_helper'
require 'ciri/pow'
require 'ciri/utils'

RSpec.describe Ciri::POW do

  it 'check_pow' do
    block_number = 1
    mining = Ciri::Utils.hex_to_data '85913a3057ea8bec78cd916871ca73802e77724e014dda65add3405d02240eb7'
    mix_hash = Ciri::Utils.hex_to_data('0x969b900de27b6ac6a67742365dd65f55a0526c41fd18e1b16f1a1215c2e66f59')
    nonce = Ciri::Utils.hex_to_data('0x539bd4979fef1ec4')
    difficulty = 17171480576

    # not satisfy difficulty
    expect do
      Ciri::POW.check_pow(block_number, mining, mix_hash, nonce, 2 ** 256)
    end.to raise_error(Ciri::POW::InvalidError)

    # not satisfy mix_hash
    expect do
      Ciri::POW.check_pow(block_number, mining, "\x00".b * 32, nonce, difficulty)
    end.to raise_error(Ciri::POW::InvalidError)

    expect do
      Ciri::POW.check_pow(block_number, mining, mix_hash, nonce, difficulty)
    end.to_not raise_error

  end

  it 'mine_pow_nonce' do
    block_number = 42
    mining = "\x00".b * 32
    difficulty = 1

    mix_hash, nonce = Ciri::POW.mine_pow_nonce(block_number, mining, difficulty)

    expect do
      Ciri::POW.check_pow(block_number, mining, mix_hash, nonce, difficulty)
    end.to_not raise_error
  end

  context 'check pow with real blocks' do
    let(:blocks) {load_blocks('blocks')}

    it 'check blocks pow' do

      blocks[1..5].each do |block|
        block_number = block.header.number
        mining = block.header.mining_hash
        mix_hash = block.header.mix_hash
        nonce = block.header.nonce
        difficulty = block.header.difficulty

        expect do
          Ciri::POW.check_pow(block_number, mining, mix_hash, nonce, difficulty)
        end.to_not raise_error
      end

    end
  end

end
