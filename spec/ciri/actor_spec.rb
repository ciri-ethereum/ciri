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
