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
