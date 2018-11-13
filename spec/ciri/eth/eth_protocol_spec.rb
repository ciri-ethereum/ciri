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

require 'spec_helper'
require 'async/queue'
require 'ciri/eth/eth_protocol'
require 'ciri/p2p/rlpx'
require 'ciri/p2p/node'
require 'ciri/p2p/peer'
require 'ciri/p2p/peer_store'
require 'ciri/p2p/protocol'
require 'ciri/p2p/protocol_io'
require 'ciri/p2p/network_state'
require 'ciri/pow_chain/chain'
require 'ciri/db/backend/rocks'
require 'ciri/key'

RSpec.describe Ciri::Eth::EthProtocol do

  context 'syncing' do
    let(:blocks) do
      load_blocks('blocks')
    end
    let(:tmp_dir) {Dir.mktmpdir}
    let(:store) {Ciri::DB::Backend::Rocks.new tmp_dir}
    let(:fork_config) {Ciri::Forks::Config.new([[0, Ciri::Forks::Frontier::Schema.new]])}
    let(:chain) {Ciri::POWChain::Chain.new(store, genesis: blocks[0], network_id: 0, fork_config: fork_config)}
    let(:peer_store) { Ciri::P2P::PeerStore.new }

    after do
      # clear db
      store.close
      FileUtils.remove_entry tmp_dir
    end

    # a fake frame_io to simulate the connection
    let(:mock_frame_io) do
      Class.new do
        def initialize(read:, write:, name: '')
          @read = read
          @write = write
          @name = name
        end

        def send_data(code, data)
          msg = Ciri::P2P::RLPX::Message.new(code: code, size: data.size, payload: data)
          write_msg(msg)
        end

        def write_msg(msg)
          content = msg.rlp_encode
          @write.enqueue "#{content.length};#{content}"
        end

        def read_msg
          io = StringIO.new(@read.dequeue)
          len = io.readline(sep = ';').to_i
          Ciri::P2P::RLPX::Message.rlp_decode io.read(len)
        end

      end
    end

    def send_data(queue, code, data)
      msg = Ciri::P2P::RLPX::Message.new(code: code, size: data.size, payload: data)
      queue.enqueue msg
    end

    def read_msg(queue)
      queue.dequeue
    end

    it 'handle eth protocol, and start syncing blocks' do
      eth_protocol = Ciri::Eth::EthProtocol.new(name: 'eth', version: 63, length: 17, chain: chain)
      message_queue = Async::Queue.new
      receive_queue = Async::Queue.new

      allow_any_instance_of(Ciri::P2P::ProtocolContext).to receive(:send_data) do |receiver, code, data|
        msg = Ciri::P2P::RLPX::Message.new(code: code, size: data.size, payload: data)
        receive_queue.enqueue(msg)
      end

      caps = [Ciri::P2P::RLPX::Cap.new(name: 'eth', version: 63)]
      peer_id = Ciri::Key.random.raw_public_key[1..-1]
      hs = Ciri::P2P::RLPX::ProtocolHandshake.new(version: 0, name: 'test', caps: caps, listen_port: 30303, id: peer_id)
      peer = Ciri::P2P::Peer.new(nil, hs, [], way_for_connection: :incoming)

      Async::Reactor.run do |task|
        # start eth protocol
        task.async do
          context = Ciri::P2P::ProtocolContext.new(nil, peer: peer)
          peer = nil
          eth_protocol.initialized(context)
          eth_protocol.connected(context)
          while (msg = message_queue.dequeue)
            eth_protocol.received(context, msg)
          end
          eth_protocol.disconnected(context)
        end

        # our test cases
        task.async do |task|
          # receive status from peer
          status = Ciri::Eth::Status.rlp_decode read_msg(receive_queue).payload
          expect(status.network_id).to eq 1
          expect(status.total_difficulty).to eq chain.total_difficulty
          expect(status.genesis_block).to eq chain.genesis.get_hash

          # send status to peer
          status = Ciri::Eth::Status.new(
            protocol_version: status.protocol_version,
            network_id: status.network_id,
            total_difficulty: 68669161470,
            current_block: blocks[3].get_hash,
            genesis_block: status.genesis_block)
          send_data(message_queue, Ciri::Eth::Status::CODE, status.rlp_encode)

          # should receive get_header
          msg = read_msg(receive_queue)
          get_block_bodies = Ciri::Eth::GetBlockHeaders.rlp_decode msg.payload
          # peer should request for current head
          expect(get_block_bodies.hash_or_number).to eq blocks[3].get_hash

          block_headers = Ciri::Eth::BlockHeaders.new(headers: [blocks[3].header])
          send_data(message_queue, Ciri::Eth::BlockHeaders::CODE, block_headers.rlp_encode)

          # simulate peer actions, until peer synced latest block
          last_header = loop do
            get_block_bodies = Ciri::Eth::GetBlockHeaders.new(hash_or_number: Ciri::Eth::HashOrNumber.new(3),
                                                              amount: 1, skip: 0, reverse: false)
            send_data(message_queue, Ciri::Eth::GetBlockHeaders::CODE, get_block_bodies.rlp_encode)

            msg = read_msg(receive_queue)
            case msg.code
            when Ciri::Eth::GetBlockHeaders::CODE
              get_block_bodies = Ciri::Eth::GetBlockHeaders.rlp_decode msg.payload
              block = blocks.find {|b| b.get_hash == get_block_bodies.hash_or_number || b.number == get_block_bodies.hash_or_number}
              headers = block ? [block.header] : []
              block_headers = Ciri::Eth::BlockHeaders.new(headers: headers)
              send_data(message_queue, Ciri::Eth::BlockHeaders::CODE, block_headers.rlp_encode)
            when Ciri::Eth::GetBlockBodies::CODE
              get_block_bodies = Ciri::Eth::GetBlockBodies.rlp_decode msg.payload
              bodies = []
              get_block_bodies.hashes.each do |hash|
                b = blocks.find {|b| hash == b.get_hash}
                bodies << Ciri::Eth::BlockBodies::Bodies.new(transactions: b.transactions, ommers: b.ommers)
              end
              block_bodies = Ciri::Eth::BlockBodies.new(bodies: bodies)
              send_data(message_queue, Ciri::Eth::BlockBodies::CODE, block_bodies.rlp_encode)
            when Ciri::Eth::BlockHeaders::CODE
              block_headers = Ciri::Eth::BlockHeaders.rlp_decode msg.payload
              break block_headers.headers[0] if !block_headers.headers.empty? && block_headers.headers[0].number == 3
            else
              raise "unknown code #{msg.code}"
            end
          end

          expect(last_header).to eq blocks[3].header
          # A hack to cancel timers from reactor, so we don't need to wait for timers
          task.reactor.instance_variable_get(:@timers).cancel
          task.reactor.stop
        end
      end
    end

  end
end

