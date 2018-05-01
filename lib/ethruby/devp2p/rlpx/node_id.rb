# frozen_string_literal: true
#
# RLPX
require 'ethruby/key'

module Eth
  module DevP2P
    module RLPX

      # present node id
      class NodeID
        attr_reader :public_key

        alias key public_key

        def initialize(public_key)
          unless public_key.is_a?(Eth::Key)
            raise TypeError.new("expect Eth::Key but get #{public_key.class}")
          end
          @public_key = public_key
        end

        def id
          @id ||= key.raw_public_key[1..-1]
        end

        def == (other)
          self.class == other.class && id == other.id
        end
      end
    end
  end
end
