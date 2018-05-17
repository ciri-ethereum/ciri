# frozen_string_literal: true

require 'ethruby/utils'

module ETH
  module RLP

    # represent bool types: true | false
    class Bool
      ENCODED_TRUE = ETH::Utils.big_endian_encode(0x01)
      ENCODED_FALSE = ETH::Utils.big_endian_encode(0x00)
    end

    # Serializable module allow ruby objects serialize/deserialize to or from RLP encoding.
    # See ETH::RLP::Serializable::TYPES for supported type.
    #
    # schema method define ordered data structure for class, and determine how to encoding objects.
    #
    # schema follow `{attr_name: type}` format,
    # if attr is raw type(string or array of string), you can just use `:attr_name` to define it
    # schema simple types include Integer, Bool, String, Array...
    #
    # schema also support complex types: array and serializable.
    #
    # array types represented as `{attr_name: [type]}`, for example: `{bills: [Integer]}` means value of bill attr is an array of integer
    # serializable type represent value of attr is a RLP serializable object
    #
    #
    # Examples:
    #
    #   class AuthMsgV4
    #     include ETH::RLP::Serializable
    #
    #     # define schema
    #     schema [
    #              :signature, # raw type: string
    #              {initiator_pubkey: MySerializableKey}, # this attr is a RLP serializable object
    #              {nonce: [Integer]},
    #              {version: Integer}
    #            ]
    #
    #     # default values
    #     default_data(got_plain: false)
    #   end
    #
    #   msg = AuthMsgV4.new(signature: "\x00", initiator_pubkey: my_pubkey, nonce: [1, 2, 3], version: 4)
    #   encoded = msg.rlp_encode!
    #   msg2 = AuthMsgV4.rlp_decode!(encoded)
    #   msg == msg2 # true
    #
    module Serializable
      # nil represent RLP raw value(string or array of string)
      TYPES = [nil, Integer, Bool].map {|key| [key, true]}.to_h.freeze

      # Schema specific columns types of classes, normally you should not use Serializable::Schema directly
      #
      class Schema
        class InvalidSchemaError < StandardError
        end

        # keys return data columns array
        attr_reader :keys

        def initialize(schema)
          keys = []
          @_schema = {}

          schema.each do |key|
            key, type = key.is_a?(Hash) ? key.to_a[0] : [key, nil]
            raise InvalidSchemaError.new("missing type #{type} for key #{key}") unless check_key_type(type)
            keys << key
            @_schema[key] = type
          end

          @_schema.freeze
          @keys = keys.freeze
        end

        # Get column type, see Serializable::TYPES for supported type
        def [](key)
          @_schema[key]
        end

        # Validate data, data is a Hash
        def validate!(data)
          keys.each do |key|
            raise InvalidSchemaError.new("missing key #{key}") unless data.key?(key)
          end
        end

        def rlp_encode!(data, raw: true)
          # pre-encode, encode data to rlp compatible format(only string or array)
          data_list = keys.map do |key|
            Serializable.encode_with_type(data[key], self[key])
          end
          raw ? RLP.encode(data_list) : data_list
        end

        def rlp_decode!(input, raw: true)
          data = raw ? RLP.decode(input) : input
          keys.each_with_index.map do |key, i|
            # decode data by type
            decoded_item = Serializable.decode_with_type(data[i], self[key])
            [key, decoded_item]
          end.to_h
        end


        private
        def check_key_type(type)
          return true if TYPES.key?(type)
          return true if type.is_a?(Class) && type < Serializable

          if type.is_a?(Array) && type.size == 1
            check_key_type(type[0])
          else
            false
          end
        end
      end

      module ClassMethods
        # Decode object from input
        def rlp_decode(input, raw: true)
          data = schema.rlp_decode!(input, raw: raw)
          self.new(data)
        end

        alias rlp_decode! rlp_decode

        def schema(data_schema = nil)
          @data_schema ||= Schema.new(data_schema).tap do |schema|
            # define attributes methods
            define_attributes(schema)
          end
        end

        def default_data(data = nil)
          @default_data ||= data
        end

        private
        def define_attributes(schema)
          schema.keys.each do |attribute|
            module_eval <<-ATTR_METHODS
            def #{attribute}
              data[:"#{attribute}"]
            end

            def #{attribute}=(value)
              data[:"#{attribute}"] = value 
            end
            ATTR_METHODS
          end
        end
      end

      class << self
        def included(base)
          base.send :extend, ClassMethods
        end

        # use this method before RLP.encode
        # encode item to string or array
        def encode_with_type(item, type, zero: '')
          if type == Integer
            if item == 0
              "\x80".b
            elsif item < 128
              ETH::Utils.big_endian_encode(item, zero)
            else
              buf = ETH::Utils.big_endian_encode(item, zero)
              [0x80 + buf.size].pack("c*") + buf
            end
          elsif type == Bool
            item ? Bool::ENCODED_TRUE : Bool::ENCODED_FALSE
          elsif type.is_a?(Class) && type < Serializable
            item.rlp_encode!(raw: false)
          elsif type.is_a?(Array)
            if type.size == 1 # array type
              item.map {|i| encode_with_type(i, type[0])}
            else # unknown
              raise InvalidValueError.new "type size should be 1, got #{type}"
            end
          else
            raise InvalidValueError.new "unknown type #{type}" unless TYPES.key?(type)
            item
          end
        end

        # Use this method after RLP.decode, decode values from string or array to specific types
        # see ETH::RLP::Serializable::TYPES for supported types
        #
        # Examples:
        #
        #   item = ETH::RLP.decode(encoded_text)
        #   decode_with_type(item, Integer)
        #
        def decode_with_type(item, type)
          if type == Integer
            if item == "\x80".b || item.empty?
              0
            elsif item[0].ord < 0x80
              ETH::Utils.big_endian_decode(item)
            else
              size = item[0].ord - 0x80
              ETH::Utils.big_endian_decode(item[1..size])
            end
          elsif type == Bool
            if item == Bool::ENCODED_TRUE
              true
            elsif item == Bool::ENCODED_FALSE
              false
            else
              raise InvalidValueError.new "invalid bool value #{item}"
            end
          elsif type.is_a?(Class) && type < Serializable
            # already decoded from RLP encoding
            type.rlp_decode!(item, raw: false)
          elsif type.is_a?(Array)
            item.map {|i| decode_with_type(i, type[0])}
          else
            raise InvalidValueError.new "unknown type #{type}" unless TYPES.key?(type)
            item
          end
        end
      end

      attr_reader :data

      def initialize(**data)
        @data = (self.class.default_data || {}).merge(data)
        self.class.schema.validate!(@data)
      end

      # Encode object to rlp encoding string
      def rlp_encode!(raw: true)
        self.class.schema.rlp_encode!(data, raw: raw)
      end

      def ==(other)
        self.class == other.class && data == other.data
      end

    end
  end
end
