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

    # protocol represent DevP2P sub protocols
    class Protocol

      attr_reader :name, :version, :length
      attr_accessor :node_info, :peer_info

      def initialize(name:, version:, length:)
        @name = name
        @version = version
        @length = length
        @start = nil
      end

      def start=(start_proc)
        @start = start_proc
      end

      def start(peer, io)
        raise NotImplementedError.new('not set protocol start proc') unless @start
        @start.call(peer, io)
      end
    end

  end
end
