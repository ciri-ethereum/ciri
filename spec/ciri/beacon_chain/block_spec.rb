# frozen_string_literal: true

# Copyright (c) 2018 by Jiang Jinyang <jjyruby@gmail.com>
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
require 'ciri/beacon_chain/block'

RSpec.describe Ciri::BeaconChain::Block do

  it 'new' do
    block = described_class.new(
      parent_hash: Ciri::Types::Hash32.new("\x01".b * 32),
      slot_number: 1,
      randao_reveal: Ciri::Types::Hash32.new("\x99".b * 32),
      attestations: [],
      pow_chain_ref: Ciri::Types::Hash32.new("\x51".b * 32),
      active_state_root: Ciri::Types::Hash32.new("\x00".b * 32),
      crystallized_state_root: Ciri::Types::Hash32.new("\x11".b * 32),
    )
    decoded_block = described_class.rlp_decode described_class.rlp_encode(block)
    expect(block).to eq decoded_block
  end

end
