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
require 'ciri/chain/transaction'
require 'ciri/key'

RSpec.describe Ciri::Chain::Transaction do

  it 'sign' do
    t = Ciri::Chain::Transaction.new(nonce: 1, gas_price: 1, gas_limit: 5, to: 0x00, value: 0)
    key = Ciri::Key.random
    t.sign_with_key! key
    expect(t.sender.to_s).to eq Ciri::Utils.keccak(key.raw_public_key[1..-1])[-20..-1]
  end

end
