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
require 'ciri/types/hash'

RSpec.describe Ciri::Types::Hash32 do

  it 'RLP' do
    hash32 = described_class.new("\x00" * 32)
    decoded_hash32 = described_class.rlp_decode described_class.rlp_encode(hash32)
    expect(hash32).to eq decoded_hash32
  end

  it 'size must be 32' do
    expect do
      described_class.new("\x00" * 20).validate
    end.to raise_error(Ciri::Types::Errors::InvalidError)
  end

end

