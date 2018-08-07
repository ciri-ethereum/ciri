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


require 'stringio'

module Ciri
  module RLP
    module Decode

      # Decode input from rlp encoding, only produce string or array
      #
      # Examples:
      #
      #   Ciri::RLP.decode(input)
      #
      def decode(input, type = Raw)
        decode_with_type(input, type)
      end

      # Use this method after RLP.decode, decode values from string or array to specific types
      # see Ciri::RLP::Serializable::TYPES for supported types
      #
      # Examples:
      #
      #   item = Ciri::RLP.decode(encoded_text)
      #   decode_with_type(item, Integer)
      #
      def decode_with_type(s, type)
        s = StringIO.new(s) if s.is_a?(String)
        if type == Integer
          item = s.read(1)
          if item.nil?
            raise InvalidError.new "invalid bool value nil"
          elsif item == "\x80".b || item.empty?
            0
          elsif item.ord < 0x80
            item.ord
          else
            size = item[0].ord - 0x80
            Ciri::Utils.big_endian_decode(s.read(size))
          end
        elsif type == Bool
          item = s.read(1)
          if item == Bool::ENCODED_TRUE
            true
          elsif item == Bool::ENCODED_FALSE
            false
          else
            raise InvalidError.new "invalid bool value #{item}"
          end
        elsif type.is_a?(Class) && type.respond_to?(:rlp_decode)
          type.rlp_decode(s)
        elsif type.is_a?(Array)
          decode_list(s) do |list, s2|
            i = 0
            until s2.eof?
              t = type.size > i ? type[i] : type[-1]
              list << decode_with_type(s2, t)
              i += 1
            end
          end
        elsif type == Raw
          decode_stream(s)
        else
          raise RLP::InvalidError.new "unknown type #{type}"
        end
      rescue
        STDERR.puts "when decoding #{s} into #{type}"
        raise
      end

      protected

      def decode_list(s, first_char = nil, &decoder)
        s = StringIO.new(s) if s.is_a?(String)
        c = first_char || s.read(1)
        list = []

        sub_s = case c.ord
                when 0xc0..0xf7
                  length = c.ord - 0xc0
                  s.read(length)
                when 0xf8..0xff
                  length_binary = s.read(c.ord - 0xf7)
                  length = int_from_binary(length_binary)
                  s.read(length)
                else
                  raise InvalidError.new("invalid char #{c}")
                end

        decoder.call(list, StringIO.new(sub_s))
        list
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
        else
          decode_list(s, c) do |list, s2|
            until s2.eof?
              list << decode_stream(s2)
            end
          end
        end
      end

      def int_from_binary(input)
        Ciri::Utils.big_endian_decode(input)
      end

    end
  end
end