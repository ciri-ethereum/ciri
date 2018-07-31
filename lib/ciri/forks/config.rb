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
  module Forks

    class Config

      # @schema_rule [[0, Frontier], [100, Homestead]]
      def initialize(schema_rules)
        @schema_rules = schema_rules
      end

      def choose_fork(number)
        @schema_rules.reverse_each.find do |start_number, _schema|
          number >= start_number
        end[1]
      end

    end

  end
end
