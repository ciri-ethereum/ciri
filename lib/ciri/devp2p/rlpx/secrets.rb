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
