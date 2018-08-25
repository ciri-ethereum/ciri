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


require 'ciri/key'
require 'ciri/rlp/serializable'

module Ciri
  module DevP2P
    module RLPX
      MESSAGES = {
          handshake: 0x00,
          discover: 0x01,
          ping: 0x02,
          pong: 0x03
      }.freeze

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
