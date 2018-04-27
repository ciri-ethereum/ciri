module Reth
  module RLP
    module Encode

      class InputOverflow < StandardError
      end

      class << self

        def encode(input)
          result = if input.is_a?(String)
                     encode_string(input)
                   elsif input.is_a?(Array)
                     encode_list(input)
                   elsif input.is_a?(Numeric)
                     to_binary(input)
                   elsif input == true
                     to_binary(0x01)
                   elsif input == false
                     to_binary(0x80)
                   else
                     raise ArgumentError.new('input must be a String or Array')
                   end
          result.b
        end

        private
        def encode_string(input)
          length = input.length
          if length == 1 && input.ord < 0x80
            input
          elsif length < 56
            to_binary(0x80 + length) + input
          elsif length < 256 ** 8
            binary_length = to_binary(length)
            to_binary(0xb7 + binary_length.size) + binary_length + input
          else
            raise InputOverflow.new("input length #{input.size} is too long")
          end
        end

        def encode_list(input)
          output = input.map {|item| encode(item)}.join
          length = output.length
          if length < 56
            to_binary(0xc0 + length) + output
          elsif length < 256 ** 8
            binary_length = to_binary(length)
            to_binary(0xf7 + binary_length.size) + binary_length + output
          else
            raise InputOverflow.new("input length #{input.size} is too long")
          end
        end

        def to_binary(n)
          if n == 0
            ''
          else
            to_binary(n / 256) + (n % 256).chr
          end
        end

      end
    end
  end
end