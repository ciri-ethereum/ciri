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
require 'ciri/pow_chain/ethash/ffi_ethash'

RSpec.describe Ciri::POWChain::Ethash::FFIEthash do

  it 'mkcache_bytes' do
    bytes = Ciri::POWChain::Ethash::FFIEthash.mkcache_bytes(15)
    expect(bytes.size).to eq 16776896
  end

  it 'hashimoto_light' do
    cache = Ciri::POWChain::Ethash::FFIEthash.mkcache_bytes(1024)
    block_number = 1024
    header = "~~~~~X~~~~~~~~~~~~~~~~~~~~~~~~~~".b

    mix_hash, result = Ciri::POWChain::Ethash::FFIEthash.hashimoto_light(block_number, cache, header, 0)

    expect(mix_hash.size).to eq 32
    expect(result.size).to eq 32
  end

end
