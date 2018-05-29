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


require 'ciri/chain'
require 'ciri/rlp'
require 'stringio'

module Ciri
  module Eth

    # represent a hash or a number
    class HashOrNumber
      include Ciri::RLP::Serializable

      attr_reader :value

      def initialize(value)
        @value = value
      end

      def rlp_encode!
        if value.is_a? Integer
          RLP.encode(value, Integer)
        else
          RLP.encode(value)
        end
      end

      def self.rlp_decode!(s)
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

      def rlp_encode!
        Ciri::RLP.encode(@headers, [Chain::Header])
      end

      def self.rlp_decode!(payload)
        new headers: Ciri::RLP.decode(payload, [Chain::Header])
      end
    end

    class GetBlockBodies
      CODE = 0x05

      attr_reader :hashes

      def initialize(hashes:)
        @hashes = hashes
      end

      def rlp_encode!
        Ciri::RLP.encode(@hashes)
      end

      def self.rlp_decode!(payload)
        new hashes: Ciri::RLP.decode(payload)
      end
    end

    class BlockBodies
      CODE = 0x06

      class Bodies
        include RLP::Serializable

        schema [
                 {transactions: [Chain::Transaction]},
                 {ommers: [Chain::Header]},
               ]
      end

      attr_reader :bodies

      def initialize(bodies:)
        @bodies = bodies
      end

      def rlp_encode!
        Ciri::RLP.encode(@bodies, [Bodies])
      end

      def self.rlp_decode!(bodies)
        new bodies: Ciri::RLP.decode(bodies, [Bodies])
      end
    end

  end
end