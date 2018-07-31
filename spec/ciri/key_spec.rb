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
require 'ciri/crypto'
require 'ciri/key'

RSpec.describe Ciri::Key do
  context 'ecdsa recover' do
    it 'self consistent' do
      key = Ciri::Key.random
      msg = Ciri::Utils.keccak "hello world"
      signature = key.ecdsa_signature(msg)
      expect(Ciri::Key.ecdsa_recover(msg, signature).raw_public_key).to eq key.raw_public_key
    end
  end
end
