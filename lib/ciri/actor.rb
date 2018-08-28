# frozen_string_literal: true

# Copyright (c) 2018 by Jiang Jinyang <jjyruby@gmail.com>
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

  # simple actor model implementation
  # Example:
  #
  #   class Hello
  #     include Actor
  #
  #     def say_hello
  #       puts 'hello world'
  #       'hello world'
  #     end
  #   end
  #
  #   actor = Hello.new()
  #   # start actor loop
  #   actor.start
  #   # push message to actor inbox
  #   actor << :say_hello
  #   # push message and wait until get response
  #   actor.call(:say_hello).value
  #
  #   # raise error
  #   actor.call(:hello).value # NoMethodError
  #
  #   # stop actor
  #   actor.send_stop
  #   actor.wait
  #
  module Actor

    LOGGER = Logger.new(STDERR, datetime_format: '%Y-%m-%d %H:%M:%S', level: Logger::INFO)

    # future, use this to wait actor msg respond
    class Future
      def initialize
        @value = nil
        @done = false
        @queue = Queue.new
      end

      def value=(val)
        if @done
          raise RuntimeError.new('future value duplicated set')
        end
        @done = true
        @queue << :done if @queue
        @value = val
      end

      def value
        loop do
          if @done
            return @value
          elsif @error
            raise @error
          else
            @queue.pop
          end
        end
      end

      def raise_error(error)
        error.set_backtrace(caller) if error.backtrace.nil?
        @error = error
        @queue << :error if @queue
      end
    end

    class Error < StandardError
    end

    # stop actor
    class StopError < Error
    end

    class StateError < Error
    end

    class << self
      attr_accessor :default_executor
    end

    attr_accessor :executor

    def initialize(executor: Actor.default_executor)
      @inbox = Queue.new
      @executor = executor
      @future = Future.new
      @running = false
    end

    # async call
    def enqueue(method, *args)
      self << [method, *args]
    end

    def <<(args)
      @inbox << args
    end

    # sync call, push msg to inbox, and return future
    #
    # Example:
    #   future = actor.call(:result) # future
    #   future.value # blocking and wait for result
    #
    def call(method, *args)
      future = Future.new
      self << [future, method, *args]
      future
    end

    # start actor
    def start
      raise Error.new("must set executor before start") unless executor

      @running = true
      executor.post do
        start_loop
      end
    end

    # send stop to actor
    #
    # Example:
    #   actor.send_stop
    #   # wait for actor actually stopped
    #   actor.wait
    #
    def send_stop
      self << [:raise_error, StopError.new]
    end

    # wait until an error occurs
    def wait
      raise StateError.new('actor not running!') unless @running
      @future.value
    end

    # start loop
    def start_loop
      loop_callback do |wait_message: true|
        # check inbox
        next Thread.pass if @inbox.empty? && !wait_message
        msg = @inbox.pop

        # extract sync or async call
        future = nil
        method, *args = msg
        if method.is_a?(Future)
          future = method
          method, *args = args
        end
        begin
          val = send(method, *args)
        rescue StandardError => e
          future.raise_error(e) if future
          raise
        end
        # if future not nil, set value
        future.value = val if future
      end until @inbox.closed?

    rescue StopError
      # actor stop
      @future.value = nil
    rescue StandardError => e
      @future.raise_error e
      LOGGER.error("Actor #{self}") {"#{e}\n#{e.backtrace.join("\n")}"}
    ensure
      @running = false
      @inbox.close
    end

    # allow inject callback into actor loop
    # Example:
    #
    #   class A
    #     include Actor
    #
    #     def loop_callback
    #       # before handle msg
    #       yield
    #       # after handle msg
    #     end
    #   end
    #
    def loop_callback
      yield
    end

    def raise_error(e)
      raise e
    end
  end

end
