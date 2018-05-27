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
require 'ciri/ethash'

RSpec.describe Ciri::Ethash do

  it 'mkcache_bytes' do
    bytes = Ciri::Ethash.mkcache_bytes(15)
    expect(bytes.size).to eq 16776896
  end

  it 'hashimoto_light' do
    cache = Ciri::Ethash.mkcache_bytes(1024)
    block_number = 1024
    header = "~~~~~X~~~~~~~~~~~~~~~~~~~~~~~~~~".b

    mix_hash, result = Ciri::Ethash.hashimoto_light(block_number, cache, header, 0)

    expect(mix_hash.size).to eq 32
    expect(result.size).to eq 32
  end

end
