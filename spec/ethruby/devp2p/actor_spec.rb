# frozen_string_literal: true

require 'concurrent'
require 'ethruby/devp2p/actor'

my_actor = Class.new do
  include ETH::DevP2P::Actor

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

RSpec.describe ETH::DevP2P::Actor do
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
    end.to raise_error(ETH::DevP2P::Actor::StateError)
  end
end
