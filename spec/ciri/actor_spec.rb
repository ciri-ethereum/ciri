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


require 'spec_helper'
require 'concurrent'
require 'ciri/actor'

my_actor = Class.new do
  include Ciri::Actor

  def histories
    @histories ||= []
  end

  def hello
    'hello'.tap {|i| histories << i}
  end

  def world
    'world'.tap {|i| histories << i}
  end

  def echo(*args)
    args.tap {|i| histories << i}
  end

  def error(e, delay = 0)
    sleep(delay)
    raise e
  end
end

RSpec.describe Ciri::Actor do
  let(:executor) {Concurrent::FixedThreadPool.new(1)}
  let(:actor) {my_actor.new(executor: executor)}

  after {executor.kill}

  it 'async call got execute' do
    actor.start
    actor << :hello
    actor << [:echo, "this", "is", "cool"]
    actor.enqueue(:world)
    actor.send_stop
    actor.wait
    expect(actor.histories).to eq ['hello', ["this", "is", "cool"], "world"]
  end

  it 'async raise error' do
    actor.start
    actor << [:error, StandardError.new('raise from actor'), 0.01]
    expect do
      actor.wait
    end.to raise_error(StandardError, 'raise from actor')
  end

  it 'sync call' do
    actor.start
    expect(actor.call(:hello).value).to eq 'hello'
    expect(actor.call(:echo, 'sync', 'call').value).to eq ['sync', 'call']
  end

  it 'sync raise error' do
    actor.start
    future = actor.call(:error, StandardError.new('raise from future'))
    expect do
      future.value
    end.to raise_error(StandardError, 'raise from future')
  end

  it 'wait' do
    expect do
      actor.wait
    end.to raise_error(Ciri::Actor::StateError)
  end
end
