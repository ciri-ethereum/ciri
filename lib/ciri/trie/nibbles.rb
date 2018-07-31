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
        hex_s = Utils.to_hex(value)
        hex_s = hex_s[2..-1] if hex_s.start_with?('0x')
        hex_s.each_char.map {|c| c.to_i(16)}
      end

      def nibbles_to_bytes(nibbles)
        Utils.to_bytes(nibbles.map {|n| n.to_s(16)}.join)
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
