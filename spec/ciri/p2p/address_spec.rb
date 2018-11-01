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
require 'ciri/p2p/address'
require 'ciri/core_ext'

using Ciri::CoreExt

RSpec.describe Ciri::P2P::Address do
  describe Ciri::P2P::Address do
    it '#==' do
      addr1 = described_class.new(ip: '127.0.0.1', udp_port:3000, tcp_port: 3001)
      addr2 = described_class.new(ip: '127.0.0.1', udp_port:3000, tcp_port: 3001)
      expect(addr1).to eq addr2
    end

    it '#ip' do
      addr = described_class.new(ip: '127.0.0.1', udp_port:3000, tcp_port: 3001)
      expect(addr.ip.loopback?).to be true
    end
  end

end

