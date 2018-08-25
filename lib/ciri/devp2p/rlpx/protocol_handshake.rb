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


require 'ciri/rlp/serializable'

module Ciri
  module DevP2P
    module RLPX

      class Cap
        include Ciri::RLP::Serializable

        schema(
            name: RLP::Bytes,
            version: Integer
        )
      end

      # handle protocol handshake
      class ProtocolHandshake
        include Ciri::RLP::Serializable

        schema(
            version: Integer,
            name: RLP::Bytes,
            caps: [Cap],
            listen_port: Integer,
            id: RLP::Bytes
        )
        default_data(listen_port: 0)
      end

    end
  end
end
