# frozen_string_literal: true
#
#
# Message class handle message serialize/deserialize to RLP encoding
#
# Usage:
#
# class AuthMsgV4 < Eth::DevP2P::Message
#   schema [
#            {got_plain: :bool},
#            :signature,
#            :initiator_pubkey,
#            {nonce: [:int]},
#            {version: :int}
#          ]
#   default_data(got_plain: false)
#
# schema is function to define data-schema of message
#

module Eth
  module DevP2P
    class Message
      TYPES = %i{raw int bool}.map {|key| [key, true]}.to_h.freeze

      # represent message schema
      class Schema
        class InvalidSchema < StandardError
        end

        class InvalidValue < StandardError
        end

        attr_reader :keys

        def initialize(schema)
          keys = []
          @_schema = {}

          schema.each do |key|
            key, type = key.is_a?(Hash) ? key.to_a[0] : [key, :raw]
            raise InvalidSchema.new("missing type #{type} for key #{key}") unless check_key_type(type)
            keys << key
            @_schema[key] = type
          end

          @_schema.freeze
          @keys = keys.freeze
        end

        def [](key)
          @_schema[key]
        end

        def validate!(data)
          keys.each do |key|
            raise InvalidSchema.new("missing key #{key}") unless data.key?(key)
          end
        end

        # RLP Encoding

        def rlp_encode!(data)
          # pre-encode, encode data to rlp compatible format(only string or array)
          data_list = keys.map do |key|
            encode_with_type(data[key], self[key])
          end
          RLP.encode(data_list)
        end

        def rlp_decode!(input)
          data = RLP.decode(input)
          keys.each_with_index.map do |key, i|
            # decode data by type
            decoded_item = decode_with_type(data[i], self[key])
            [key, decoded_item]
          end.to_h
        end


        private
        def check_key_type(type)
          return true if TYPES.key?(type)

          if type.is_a?(Array) && type.size == 1
            check_key_type(type[0])
          else
            false
          end
        end

        def encode_with_type(item, type)
          if type == :int
            Eth::Utils.big_endian_encode(item)
          elsif type == :bool
            Eth::Utils.big_endian_encode(item ? 0x01 : 0x80)
          elsif type.is_a?(Array)
            item.map {|i| encode_with_type(i, type[0])}
          else
            item
          end
        end

        def decode_with_type(item, type)
          if type == :int
            Eth::Utils.big_endian_decode(item)
          elsif type == :bool
            if item == Eth::Utils.big_endian_encode(0x01)
              true
            elsif item == Eth::Utils.big_endian_encode(0x80)
              false
            else
              raise InvalidValue.new "invalid bool value #{item}"
            end
          elsif type.is_a?(Array)
            item.map {|i| decode_with_type(i, type[0])}
          else
            item
          end
        end
      end

      class InvalidData < StandardError
      end

      class << self
        def rlp_decode(input)
          data = schema.rlp_decode!(input)
          self.new(data)
        end

        alias rlp_decode! rlp_decode

        def schema(data_schema = nil)
          @data_schema ||= Schema.new(data_schema)
        end

        def default_data(data = nil)
          @default_data ||= data
        end
      end

      attr_reader :data

      def initialize(**data)
        @data = (self.class.default_data || {}).merge(data)
        self.class.schema.validate!(@data)
      end

      def rlp_encode!
        self.class.schema.rlp_encode!(data)
      end

      def ==(other)
        self.class == other.class && data == other.data
      end

      def method_missing(method, *args)
        if args.size == 0 && data.key?(method)
          return data[method]
        end
        super
      end

    end
  end
end
