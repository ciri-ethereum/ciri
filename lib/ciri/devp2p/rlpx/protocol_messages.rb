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


require 'ciri/key'
require 'ciri/rlp/serializable'

module Ciri
  module DevP2P
    module RLPX
      # RLPX protocol code
      module Code
        HANDSHAKE = 0x00
        DISCONNECT = 0x01
        PING = 0x02
        PONG = 0x03
      end

      BASE_PROTOCOL_VERSION = 5
      BASE_PROTOCOL_LENGTH = 16
      BASE_PROTOCOL_MAX_MSG_SIZE = 2 * 1024
      SNAPPY_PROTOCOL_VERSION = 5

      ### messages

      class AuthMsgV4
        include Ciri::RLP::Serializable

        schema(
            signature: RLP::Bytes,
            initiator_pubkey: RLP::Bytes,
            nonce: RLP::Bytes,
            version: Integer
        )

        # keep this field let client known how to format(plain or eip8)
        attr_accessor :got_plain
      end

      class AuthRespV4
        include Ciri::RLP::Serializable

        schema(
            random_pubkey: RLP::Bytes,
            nonce: RLP::Bytes,
            version: Integer
        )
      end
    end
  end
end
