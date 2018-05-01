# frozen_string_literal: true

module Eth
  module DevP2P
    module RLPX

      # class used to store rplx protocol secrets
      class Secrets
        attr_reader :remote_id, :aes, :mac
        attr_accessor :egress_mac, :ingress_mac

        def initialize(remote_id: nil, aes:, mac:)
          @remote_id = remote_id
          @aes = aes
          @mac = mac
        end

        def ==(other)
          self.class == other.class &&
            remote_id == other.remote &&
            aes == other.aes &&
            mac == other.mac
        end
      end

    end
  end
end
