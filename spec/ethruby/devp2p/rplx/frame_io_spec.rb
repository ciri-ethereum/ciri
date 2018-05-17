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


require 'socket'
require 'ethruby/devp2p/rlpx'
require 'ethruby/rlp'

RSpec.describe ETH::DevP2P::RLPX::FrameIO do
  it 'write_msg and read_msg' do
    aes_secret = 16.times.map {rand 8}.pack('c*')
    mac_secret = 16.times.map {rand 8}.pack('c*')
    egress_mac_init = 32.times.map {rand 8}.pack('c*')
    ingress_mac_init = 32.times.map {rand 8}.pack('c*')

    r, w = IO.pipe

    s1 = ETH::DevP2P::RLPX::Secrets.new(aes: aes_secret, mac: mac_secret)
    s2 = ETH::DevP2P::RLPX::Secrets.new(aes: aes_secret, mac: mac_secret)
    s1.ingress_mac, s1.egress_mac, s2.ingress_mac, s2.egress_mac = 4.times.map {Digest::SHA3.new(256)}

    s1.egress_mac.update(egress_mac_init)
    s1.ingress_mac.update(ingress_mac_init)
    f_io1 = ETH::DevP2P::RLPX::FrameIO.new(w, s1)

    s2.egress_mac.update(ingress_mac_init)
    s2.ingress_mac.update(egress_mac_init)
    f_io2 = ETH::DevP2P::RLPX::FrameIO.new(r, s2)

    ['hello world',
     'Ethereum is awesome!',
     'You known nothing, john snow!'
    ].each_with_index do |payload, i|
      encoded_payload = ETH::RLP.encode(payload)
      f_io1.send_data(i, encoded_payload)
      msg = f_io2.read_msg
      expect(msg.code).to eq i
      expect(msg.payload).to eq encoded_payload
    end
  end

  it 'write_msg then read_msg in same time' do
    aes_secret = 16.times.map {rand 8}.pack('c*')
    mac_secret = 16.times.map {rand 8}.pack('c*')
    egress_mac_init = 32.times.map {rand 8}.pack('c*')
    ingress_mac_init = 32.times.map {rand 8}.pack('c*')

    r, w = UNIXSocket.pair

    s1 = ETH::DevP2P::RLPX::Secrets.new(aes: aes_secret, mac: mac_secret)
    s2 = ETH::DevP2P::RLPX::Secrets.new(aes: aes_secret, mac: mac_secret)
    s1.ingress_mac, s1.egress_mac, s2.ingress_mac, s2.egress_mac = 4.times.map {Digest::SHA3.new(256)}

    s1.egress_mac.update(egress_mac_init)
    s1.ingress_mac.update(ingress_mac_init)
    f_io1 = ETH::DevP2P::RLPX::FrameIO.new(w, s1)

    s2.egress_mac.update(ingress_mac_init)
    s2.ingress_mac.update(egress_mac_init)
    f_io2 = ETH::DevP2P::RLPX::FrameIO.new(r, s2)

    m1 = ETH::RLP.encode('hello world')
    m2 = ETH::RLP.encode('bye world')

    f_io1.send_data(1, m1)
    f_io2.send_data(1, m2)

    msg = f_io2.read_msg
    expect(msg.code).to eq 1
    expect(msg.payload).to eq m1
  end

end
