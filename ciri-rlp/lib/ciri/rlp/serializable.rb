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


require 'ciri/utils'

module Ciri
  module RLP

    # represent bool types: true | false
    class Bool
      ENCODED_TRUE = Ciri::Utils.big_endian_encode(0x01)
      ENCODED_FALSE = Ciri::Utils.big_endian_encode(0x80)
    end

    # represent RLP raw types, binary or array
    class Raw
    end

    class RawString
    end

    class RawList
    end

    # Serializable module allow ruby objects serialize/deserialize to or from RLP encoding.
    # See Ciri::RLP::Serializable::TYPES for supported type.
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
    #     include Ciri::RLP::Serializable
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
    #   encoded = msg.rlp_encode
    #   msg2 = AuthMsgV4.rlp_decode(encoded)
    #   msg == msg2 # true
    #
    module Serializable
      # nil represent RLP raw value(string or array of string)
      TYPES = [Raw, RawString, RawList, Integer, Bool].map {|key| [key, true]}.to_h.freeze

      # Schema specific columns types of classes, normally you should not use Serializable::Schema directly
      #
      class Schema
        include Encode
        include Decode

        class InvalidSchemaError < StandardError
        end

        # keys return data columns array
        attr_reader :keys

        KeySchema = Struct.new(:type, :options, keyword_init: true)

        def initialize(schema)
          keys = []
          @_schema = {}

          schema.each do |key|
            if key.is_a?(Hash)
              options = [:optional].map {|o| [o, key.delete(o)]}.to_h
              raise InvalidSchemaError.new("include unknown options #{key}") unless key.size == 1
              key, type = key.to_a[0]
            else
              options = {}
              type = Raw
            end
            raise InvalidSchemaError.new("missing type #{type} for key #{key}") unless check_key_type(type)
            keys << key
            @_schema[key] = KeySchema.new(type: type, options: options)
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

        def rlp_encode(data, skip_keys: nil, white_list_keys: nil)
          # pre-encode, encode data to rlp compatible format(only string or array)
          used_keys = if white_list_keys
                        white_list_keys
                      elsif skip_keys
                        keys - skip_keys
                      else
                        keys
                      end
          data_list = []
          used_keys.each do |key|
            value = data[key]
            next if value.nil? && self[key].options[:optional]
            data_list << encode_with_type(value, self[key].type)
          end
          encode_list(data_list)
        end

        def rlp_decode(input)
          values = decode_list(input) do |list, stream|
            keys.each do |key|
              # decode data by type
              next if stream.eof? && self[key].options[:optional]
              list << decode_with_type(stream, self[key].type)
            end
          end
          # convert to key value hash
          keys.zip(values).to_h
        end

        private

        def check_key_type(type)
          return true if TYPES.key?(type)
          return true if type.is_a?(Class) && type.respond_to?(:rlp_decode) && type.respond_to?(:rlp_encode)

          if type.is_a?(Array) && type.size == 1
            check_key_type(type[0])
          else
            false
          end
        end
      end

      module ClassMethods
        # Decode object from input
        def rlp_decode(input)
          data = schema.rlp_decode(input)
          self.new(data)
        end

        # Encode object to rlp encoding string
        def rlp_encode(item, skip_keys: nil, white_list_keys: nil)
          schema.rlp_encode(item.serializable_attributes, skip_keys: skip_keys, white_list_keys: white_list_keys)
        end

        def schema(data_schema = nil)
          if data_schema
            @data_schema = Schema.new(data_schema).tap do |schema|
              # define attributes methods
              define_attributes(schema)
            end
          else
            @data_schema ||= superclass.schema
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
              serializable_attributes[:"#{attribute}"]
            end

            def #{attribute}=(value)
              serializable_attributes[:"#{attribute}"] = value 
            end
            ATTR_METHODS
          end
        end
      end

      class << self
        def included(base)
          base.send :extend, ClassMethods
        end
      end

      attr_reader :serializable_attributes

      def initialize(**data)
        @serializable_attributes = (self.class.default_data || {}).merge(data)
        self.class.schema.validate!(@serializable_attributes)
      end

      def initialize_copy(orig)
        super
        @serializable_attributes = orig.serializable_attributes.dup
      end

      # Encode object to rlp encoding string
      def rlp_encode(skip_keys: nil, white_list_keys: nil)
        self.class.rlp_encode(self, skip_keys: skip_keys, white_list_keys: white_list_keys)
      end

      def ==(other)
        self.class == other.class && serializable_attributes == other.serializable_attributes
      end

    end
  end
end
