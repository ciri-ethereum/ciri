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
require 'ciri/chain'
require 'ciri/utils'

RSpec.describe Ciri::Chain::Header do

  it 'compute header hash' do
    raw_header_rlp = 'f90218a0d33c9dde9fff0ebaa6e71e8b26d2bda15ccf111c7af1b633698ac847667f0fb4a01dcc4de8dec75d7aab85b567b6ccd41ad312451b948a7413f0a142fd40d493479452bc44d5378309ee2abf1539bf71de1b7d7be3b5a0ed98aa4b5b19c82fb35364f08508ae0a6dec665fa57663dca94c5d70554cde10a0447cbd8c48f498a6912b10831cdff59c7fbfcbbe735ca92883d4fa06dcd7ae54a07fa0f6ca2a01823208d80801edad37e3e3a003b55c89319b45eb1f97862ad229b9010000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000860b6b4beb1e8e830f423f832fefd8830386588456bfb40598d783010303844765746887676f312e342e32856c696e7578a05b10f4a08a6c209d426f6158bd24b574f4f7b7aa0099c67c14a1f693b4dd04d088f491f46b60fe04b3'
    header_hash = Ciri::Utils.hex_to_data 'b4fbadf8ea452b139718e2700dc1135cfc81145031c84b7ab27cd710394f7b38'
    # get binary version
    raw_header_rlp_b = Ciri::Utils.hex_to_data raw_header_rlp
    header = Ciri::Chain::Header.rlp_decode!(raw_header_rlp_b)
    expect(header.hash).to eq header_hash
  end
end
