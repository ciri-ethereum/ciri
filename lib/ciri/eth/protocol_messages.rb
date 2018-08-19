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


require 'ciri/pow_chain/chain'
require 'ciri/rlp'
require 'stringio'

module Ciri
  module Eth

    # represent a hash or a number
    class HashOrNumber
      attr_reader :value

      class << self
        def rlp_encode(item)
          value = item.value
          if value.is_a? Integer
            RLP.encode(value, Integer)
          else
            RLP.encode(value)
          end
        end

        def rlp_decode(s)
          s = StringIO.new(s) if s.is_a?(String)
          # start with 0xA0, represent s is a 32 length hash bytes
          c = s.getc
          s.ungetc(c)
          if c.ord == 0xa0
            RLP.decode(s)
          else
            RLP.decode(s, Integer)
          end
        end
      end

      def initialize(value)
        @value = value
      end
    end

    # Ethereum Sub-protocol Messages
    #
    #


    class Status
      include Ciri::RLP::Serializable

      CODE = 0x00

      schema [
                 {protocol_version: Integer},
                 {network_id: Integer},
                 {total_difficulty: Integer},
                 :current_block,
                 :genesis_block,
             ]
    end

    class GetBlockHeaders
      include Ciri::RLP::Serializable

      CODE = 0x03

      schema [
                 {hash_or_number: HashOrNumber},
                 {amount: Integer},
                 {skip: Integer},
                 {reverse: Ciri::RLP::Bool},
             ]
    end

    class BlockHeaders
      CODE = 0x04

      attr_reader :headers

      def initialize(headers:)
        @headers = headers
      end

      def rlp_encode
        Ciri::RLP.encode(@headers, [POWChain::Header])
      end

      def self.rlp_decode(payload)
        new headers: Ciri::RLP.decode(payload, [POWChain::Header])
      end
    end

    class GetBlockBodies
      CODE = 0x05

      attr_reader :hashes

      def initialize(hashes:)
        @hashes = hashes
      end

      def rlp_encode
        Ciri::RLP.encode(@hashes)
      end

      def self.rlp_decode(payload)
        new hashes: Ciri::RLP.decode(payload)
      end
    end

    class BlockBodies
      CODE = 0x06

      class Bodies
        include RLP::Serializable

        schema [
                   {transactions: [POWChain::Transaction]},
                   {ommers: [POWChain::Header]},
               ]
      end

      attr_reader :bodies

      def initialize(bodies:)
        @bodies = bodies
      end

      def rlp_encode
        Ciri::RLP.encode(@bodies, [Bodies])
      end

      def self.rlp_decode(bodies)
        new bodies: Ciri::RLP.decode(bodies, [Bodies])
      end
    end

  end
end
