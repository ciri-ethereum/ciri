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
require 'ciri/eth/protocol_manage'
require 'ciri/devp2p/rlpx'
require 'ciri/devp2p/peer'
require 'ciri/devp2p/protocol'
require 'ciri/devp2p/protocol_io'
require 'ciri/pow_chain/chain'
require 'ciri/db/backend/rocks'
require 'ciri/key'

RSpec.describe Ciri::Eth::ProtocolManage do

  let(:blocks) do
    load_blocks('blocks')
  end
  let(:tmp_dir) {Dir.mktmpdir}
  let(:store) {Ciri::DB::Backend::Rocks.new tmp_dir}
  let(:fork_config) {Ciri::Forks::Config.new([[0, Ciri::Forks::Frontier::Schema.new]])}
  let(:chain) {Ciri::POWChain::Chain.new(store, genesis: blocks[0], network_id: 0, fork_config: fork_config)}

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
        msg = Ciri::DevP2P::RLPX::Message.new(code: code, size: data.size, payload: data)
        write_msg(msg)
      end

      def write_msg(msg)
        content = msg.rlp_encode
        @write.enqueue "#{content.length};#{content}"
      end

      def read_msg
        io = StringIO.new(@read.dequeue)
        len = io.readline(sep = ';').to_i
        Ciri::DevP2P::RLPX::Message.rlp_decode io.read(len)
      end

    end
  end

  it 'handle eth protocol, and start syncing blocks' do
    queue1, queue2 = 2.times.map {Async::Queue.new}
    peer_frame_io = mock_frame_io.new(read: queue1, write: queue2, name: 'peer')
    host_frame_io = mock_frame_io.new(read: queue2, write: queue1, name: 'host')

    eth_protocol = Ciri::DevP2P::Protocol.new(name: 'eth', version: 63, length: 17)
    protocol_manage = Ciri::Eth::ProtocolManage.new(protocols: [eth_protocol], chain: chain)

    caps = [Ciri::DevP2P::RLPX::Cap.new(name: 'eth', version: 63)]
    peer_id = Ciri::Key.random.raw_public_key[1..-1]
    hs = Ciri::DevP2P::RLPX::ProtocolHandshake.new(version: 0, name: 'test', caps: caps, listen_port: 30303, id: peer_id)
    peer = Ciri::DevP2P::Peer.new(peer_frame_io, hs, protocol_manage.protocols)
    peer_protocol_io = peer.instance_variable_get(:@protocol_io_hash).values.first
    host_protocol_io = Ciri::DevP2P::ProtocolIO.new(eth_protocol, Ciri::DevP2P::RLPX::BASE_PROTOCOL_LENGTH, host_frame_io)

    Async::Reactor.run do |task|
      # start eth protocol
      task.async do
        protocol_manage.run
        protocol_manage.new_peer(peer, peer_protocol_io)
      end

      # start peer handling loop
      task.async do
        peer.start_handling
      end

      # our test cases
      task.async do |task|
        read_msg = proc do
          msg = host_frame_io.read_msg
          # minus offset
          msg.code -= Ciri::DevP2P::RLPX::BASE_PROTOCOL_LENGTH
          msg
        end
        write_msg = proc do |code, m|
          payload = m.rlp_encode
          host_protocol_io.send_data(code, payload)
        end

        # receive status from peer
        status = Ciri::Eth::Status.rlp_decode read_msg[].payload
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
        write_msg[Ciri::Eth::Status::CODE, status]

        # should receive get_header
        msg = read_msg[]
        get_block_bodies = Ciri::Eth::GetBlockHeaders.rlp_decode msg.payload
        # peer should request for current head
        expect(get_block_bodies.hash_or_number).to eq blocks[3].get_hash

        block_headers = Ciri::Eth::BlockHeaders.new(headers: [blocks[3].header])
        write_msg[Ciri::Eth::BlockHeaders::CODE, block_headers]

        # simulate peer actions, until peer synced latest block
        last_header = loop do
          get_block_bodies = Ciri::Eth::GetBlockHeaders.new(hash_or_number: Ciri::Eth::HashOrNumber.new(3),
                                                            amount: 1, skip: 0, reverse: false)
          write_msg[Ciri::Eth::GetBlockHeaders::CODE, get_block_bodies]

          msg = read_msg[]
          case msg.code
          when Ciri::Eth::GetBlockHeaders::CODE
            get_block_bodies = Ciri::Eth::GetBlockHeaders.rlp_decode msg.payload
            block = blocks.find {|b| b.get_hash == get_block_bodies.hash_or_number || b.number == get_block_bodies.hash_or_number}
            headers = block ? [block.header] : []
            block_headers = Ciri::Eth::BlockHeaders.new(headers: headers)
            write_msg[Ciri::Eth::BlockHeaders::CODE, block_headers]
          when Ciri::Eth::GetBlockBodies::CODE
            get_block_bodies = Ciri::Eth::GetBlockBodies.rlp_decode msg.payload
            bodies = []
            get_block_bodies.hashes.each do |hash|
              b = blocks.find {|b| hash == b.get_hash}
              bodies << Ciri::Eth::BlockBodies::Bodies.new(transactions: b.transactions, ommers: b.ommers)
            end
            block_bodies = Ciri::Eth::BlockBodies.new(bodies: bodies)
            write_msg[Ciri::Eth::BlockBodies::CODE, block_bodies]
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
