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


module Ciri
  class Trie
    module Nibbles
      NIBBLE_TERMINATOR = 16

      HP_FLAG_2 = 2
      HP_FLAG_0 = 0

      extend self

      def decode_nibbles(value)
        nibbles_with_flag = bytes_to_nibbles(value)
        flag = nibbles_with_flag[0]

        needs_terminator = [HP_FLAG_2, HP_FLAG_2 + 1].include? flag
        is_odd_length = [HP_FLAG_0 + 1, HP_FLAG_2 + 1].include? flag

        raw_nibbles = if is_odd_length
                        nibbles_with_flag[1..-1]
                      else
                        nibbles_with_flag[2..-1]
                      end
        if needs_terminator
          add_nibbles_terminator(raw_nibbles)
        else
          raw_nibbles
        end
      end

      def encode_nibbles(nibbles)
        flag = if is_nibbles_terminated?(nibbles)
                 HP_FLAG_2
               else
                 HP_FLAG_0
               end
        raw_nibbles = remove_nibbles_terminator(nibbles)
        flagged_nibbles = if raw_nibbles.size.odd?
                            [flag + 1] + raw_nibbles
                          else
                            [flag, 0] + raw_nibbles
                          end
        nibbles_to_bytes(flagged_nibbles)
      end

      def remove_nibbles_terminator(nibbles)
        return nibbles[0..-2] if is_nibbles_terminated?(nibbles)
        nibbles
      end

      def bytes_to_nibbles(value)
        hex_s = Utils.data_to_hex(value)
        hex_s = hex_s[2..-1] if hex_s.start_with?('0x')
        hex_s.each_char.map {|c| c.to_i(16)}
      end

      def nibbles_to_bytes(nibbles)
        Utils.hex_to_data(nibbles.map {|n| n.to_s(16)}.join)
      end

      def is_nibbles_terminated?(nibbles)
        nibbles && nibbles[-1] == NIBBLE_TERMINATOR
      end

      def add_nibbles_terminator(nibbles)
        if is_nibbles_terminated?(nibbles)
          nibbles
        else
          nibbles + [NIBBLE_TERMINATOR]
        end
      end

    end
  end
end
