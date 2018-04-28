require 'stringio'

module Eth
  module RLP
    module Decode

      class InvalidInput < StandardError
      end

      class << self
        def decode(input)
          s = StringIO.new(input).binmode
          decode_stream(s)
        end

        private
        def decode_stream(s)
          c = s.read(1)
          case c.ord
            when 0x00..0x7f
              c
            when 0x80..0xb7
              length = c.ord - 0x80
              s.read(length)
            when 0xb8..0xbf
              length_binary = s.read(c.ord - 0xb7)
              length = int_from_binary(length_binary)
              s.read(length)
            when 0xc0..0xf7
              length = c.ord - 0xc0
              s2 = StringIO.new s.read(length)
              list = []
              until s2.eof?
                list << decode_stream(s2)
              end
              list
            when 0xf8..0xff
              length_binary = s.read(c.ord - 0xf7)
              length = int_from_binary(length_binary)
              s2 = StringIO.new s.read(length)
              list = []
              until s2.eof?
                list << decode_stream(s2)
              end
              list
            else
              raise InvalidInput.new("invalid char #{c}")
          end
        end

        def int_from_binary(input)
          Eth::Utils.big_endian_decode(input)
        end

      end
    end
  end
end