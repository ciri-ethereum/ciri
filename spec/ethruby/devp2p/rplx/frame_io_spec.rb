# frozen_string_literal: true

require 'socket'
require 'ethruby/devp2p/rlpx'
require 'ethruby/rlp'

RSpec.describe Eth::DevP2P::RLPX::FrameIO do
  it 'write_msg and read_msg' do
    aes_secret = 16.times.map {rand 8}.pack('c*')
    mac_secret = 16.times.map {rand 8}.pack('c*')
    egress_mac_init = 32.times.map {rand 8}.pack('c*')
    ingress_mac_init = 32.times.map {rand 8}.pack('c*')

    r, w = IO.pipe

    s1 = Eth::DevP2P::RLPX::Secrets.new(aes: aes_secret, mac: mac_secret)
    s2 = Eth::DevP2P::RLPX::Secrets.new(aes: aes_secret, mac: mac_secret)
    s1.ingress_mac, s1.egress_mac, s2.ingress_mac, s2.egress_mac = 4.times.map {Digest::SHA3.new(256)}

    s1.egress_mac.update(egress_mac_init)
    s1.ingress_mac.update(ingress_mac_init)
    f_io1 = Eth::DevP2P::RLPX::FrameIO.new(w, s1)

    s2.egress_mac.update(ingress_mac_init)
    s2.ingress_mac.update(egress_mac_init)
    f_io2 = Eth::DevP2P::RLPX::FrameIO.new(r, s2)

    ['hello world',
     'Ethereum is awesome!',
     'You known nothing, john snow!'
    ].each_with_index do |payload, i|
      encoded_payload = Eth::RLP.encode(payload)
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

    s1 = Eth::DevP2P::RLPX::Secrets.new(aes: aes_secret, mac: mac_secret)
    s2 = Eth::DevP2P::RLPX::Secrets.new(aes: aes_secret, mac: mac_secret)
    s1.ingress_mac, s1.egress_mac, s2.ingress_mac, s2.egress_mac = 4.times.map {Digest::SHA3.new(256)}

    s1.egress_mac.update(egress_mac_init)
    s1.ingress_mac.update(ingress_mac_init)
    f_io1 = Eth::DevP2P::RLPX::FrameIO.new(w, s1)

    s2.egress_mac.update(ingress_mac_init)
    s2.ingress_mac.update(egress_mac_init)
    f_io2 = Eth::DevP2P::RLPX::FrameIO.new(r, s2)

    m1 = Eth::RLP.encode('hello world')
    m2 = Eth::RLP.encode('bye world')

    f_io1.send_data(1, m1)
    f_io2.send_data(1, m2)

    msg = f_io2.read_msg
    expect(msg.code).to eq 1
    expect(msg.payload).to eq m1
  end

end
