# frozen_string_literal: true

# Copyright (c) 2018, by Jiang Jinyang. <https://justjjy.com>
#
# Permission is hereby granted, free of charge, to any person obtaining a copy
# of this software and associated documentation files (the "Software"), to deal
# in the Software without restriction, including without limitation the rights
# to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
# copies of the Software, and to permit persons to whom the Software is
# furnished to do so, subject to the following conditions:
#
# The above copyright notice and this permission notice shall be included in
# all copies or substantial portions of the Software.
#
# THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
# IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
# FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
# AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
# LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
# OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
# THE SOFTWARE.


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
