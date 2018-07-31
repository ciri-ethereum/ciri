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


require 'logger'

module Ciri
  module Utils

    # Logger
    # Example:
    #
    #   class A
    #     include Logger
    #
    #     def initialize(name)
    #       @name = name
    #       debug("initial with name")
    #     end
    #
    #     def greet
    #       puts "hello"
    #       debug("greeting hello")
    #     end
    #
    #     # customize logging name
    #     def logging_name
    #       "#{super}:#{@name}"
    #     end
    #   end
    #
    #   # don't forget initialize global logger
    #   Ciri::Utils::Logger.setup(level: :debug)
    #
    module Logger

      class << self
        attr_reader :global_logger

        def setup(level:)
          @global_logger = ::Logger.new(STDERR, level: level)
          global_logger.datetime_format = '%Y-%m-%d %H:%M:%S'
          set_concurrent_logger(level: global_logger.level)
        end

        private

        def set_concurrent_logger(level:)
          require 'concurrent'
          Concurrent.use_simple_logger(level = level)
        rescue LoadError
          nil
        end
      end

      def debug(message)
        add(::Logger::DEBUG, message)
      end

      def info(message)
        add(::Logger::INFO, message)
      end

      def error(message)
        add(::Logger::ERROR, message)
      end

      def logging_name
        self.class.to_s
      end

      private

      def add(severity, message = nil, progname = logging_name)
        Logger.global_logger.add(severity, message, progname)
      end

    end
  end
end
