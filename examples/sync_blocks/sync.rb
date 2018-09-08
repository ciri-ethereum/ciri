require 'ciri'
require 'ciri/devp2p/rlpx'
require 'ciri/devp2p/rlpx/protocol_handshake'
require 'ciri/devp2p/peer'
require 'ciri/utils'

include Ciri

caps = [
  Ciri::DevP2P::RLPX::Cap.new(name: 'eth', version: 63),
  Ciri::DevP2P::RLPX::Cap.new(name: 'eth', version: 62),
  Ciri::DevP2P::RLPX::Cap.new(name: 'hello', version: 1),
]
handshake = Ciri::DevP2P::RLPX::ProtocolHandshake.new(version: 4, name: 'test', caps: caps, id: 0)

# TODO complete this example

