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


require 'socket'
require 'ciri/devp2p/rlpx'
require 'ciri/rlp'

RSpec.describe Ciri::DevP2P::RLPX::FrameIO do
  it 'write_msg and read_msg' do
    aes_secret = 16.times.map {rand 8}.pack('c*')
    mac_secret = 16.times.map {rand 8}.pack('c*')
    egress_mac_init = 32.times.map {rand 8}.pack('c*')
    ingress_mac_init = 32.times.map {rand 8}.pack('c*')

    r, w = IO.pipe

    s1 = Ciri::DevP2P::RLPX::Secrets.new(aes: aes_secret, mac: mac_secret)
    s2 = Ciri::DevP2P::RLPX::Secrets.new(aes: aes_secret, mac: mac_secret)
    s1.ingress_mac, s1.egress_mac, s2.ingress_mac, s2.egress_mac = 4.times.map {Digest::SHA3.new(256)}

    s1.egress_mac.update(egress_mac_init)
    s1.ingress_mac.update(ingress_mac_init)
    f_io1 = Ciri::DevP2P::RLPX::FrameIO.new(w, s1)

    s2.egress_mac.update(ingress_mac_init)
    s2.ingress_mac.update(egress_mac_init)
    f_io2 = Ciri::DevP2P::RLPX::FrameIO.new(r, s2)

    ['hello world',
     'Ethereum is awesome!',
     'You known nothing, john snow!'
    ].each_with_index do |payload, i|
      encoded_payload = Ciri::RLP.encode(payload)
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

    s1 = Ciri::DevP2P::RLPX::Secrets.new(aes: aes_secret, mac: mac_secret)
    s2 = Ciri::DevP2P::RLPX::Secrets.new(aes: aes_secret, mac: mac_secret)
    s1.ingress_mac, s1.egress_mac, s2.ingress_mac, s2.egress_mac = 4.times.map {Digest::SHA3.new(256)}

    s1.egress_mac.update(egress_mac_init)
    s1.ingress_mac.update(ingress_mac_init)
    f_io1 = Ciri::DevP2P::RLPX::FrameIO.new(w, s1)

    s2.egress_mac.update(ingress_mac_init)
    s2.ingress_mac.update(egress_mac_init)
    f_io2 = Ciri::DevP2P::RLPX::FrameIO.new(r, s2)

    m1 = Ciri::RLP.encode('hello world')
    m2 = Ciri::RLP.encode('bye world')

    f_io1.send_data(1, m1)
    f_io2.send_data(1, m2)

    msg = f_io2.read_msg
    expect(msg.code).to eq 1
    expect(msg.payload).to eq m1
  end

end
