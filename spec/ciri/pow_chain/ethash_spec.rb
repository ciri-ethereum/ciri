# frozen_string_literal: true

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


require 'spec_helper'
require 'ciri/pow_chain/ethash'
require 'ciri/utils'

RSpec.describe Ciri::POWChain::Ethash do

  it 'check_pow' do
    block_number = 1
    mining = Ciri::Utils.to_bytes '85913a3057ea8bec78cd916871ca73802e77724e014dda65add3405d02240eb7'
    mix_hash = Ciri::Utils.to_bytes('0x969b900de27b6ac6a67742365dd65f55a0526c41fd18e1b16f1a1215c2e66f59')
    nonce = Ciri::Utils.to_bytes('0x539bd4979fef1ec4')
    difficulty = 17171480576

    # not satisfy difficulty
    expect do
      Ciri::POWChain::Ethash.check_pow(block_number, mining, mix_hash, nonce, 2 ** 256)
    end.to raise_error(Ciri::POWChain::Ethash::InvalidError)

    # not satisfy mix_hash
    expect do
      Ciri::POWChain::Ethash.check_pow(block_number, mining, "\x00".b * 32, nonce, difficulty)
    end.to raise_error(Ciri::POWChain::Ethash::InvalidError)

    expect do
      Ciri::POWChain::Ethash.check_pow(block_number, mining, mix_hash, nonce, difficulty)
    end.to_not raise_error

  end

  it 'mine_pow_nonce' do
    block_number = 42
    mining = "\x00".b * 32
    difficulty = 1

    mix_hash, nonce = Ciri::POWChain::Ethash.mine_pow_nonce(block_number, mining, difficulty)

    expect do
      Ciri::POWChain::Ethash.check_pow(block_number, mining, mix_hash, nonce, difficulty)
    end.to_not raise_error
  end

  context 'check pow_chain with real blocks' do
    let(:blocks) {load_blocks('blocks')}

    it 'check blocks pow_chain' do

      blocks[1..5].each do |block|
        block_number = block.header.number
        mining = block.header.mining_hash
        mix_hash = block.header.mix_hash
        nonce = block.header.nonce
        difficulty = block.header.difficulty

        expect do
          Ciri::POWChain::Ethash.check_pow(block_number, mining, mix_hash, nonce, difficulty)
        end.to_not raise_error
      end

    end
  end

end
