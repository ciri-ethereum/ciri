require 'ciri/utils'
require 'ciri/key'
require 'ciri/rlp'
require 'ciri/eth'
require 'ciri/evm'
require 'ciri/p2p/address'
require 'ciri/p2p/server'
require 'ciri/p2p/rlpx'
require 'ciri/p2p/protocol'
require 'ciri/pow_chain/chain'
require 'ciri/forks/frontier'
require 'ciri/db/backend/rocks'
require 'logger'
require 'yaml'
require 'pp'

include Ciri

Utils::Logger.setup(level: :debug)

def read_genesis_block(path)
  genesis_info = YAML.load open(path).read
  genesis_info = genesis_info.map {|k, v| [k.to_sym, v]}.to_h
  %i{extra_data logs_bloom beneficiary mix_hash nonce parent_hash receipts_root ommers_hash state_root transactions_root}.each do |i|
    genesis_info[i] = Utils.dehex(genesis_info[i])
  end
  transactions = genesis_info.delete(:transactions)
  ommers = genesis_info.delete(:ommers)
  header = POWChain::Header.new(**genesis_info)
  POWChain::Block.new(header: header, transactions: transactions, ommers: ommers)
end

def get_target_node
  if ARGV.size != 1
    puts "Usage: ruby examples/sync_blocks/sync.rb <node_id>"
    exit(1)
  end
  node_url = ARGV[0]
  Ciri::P2P::Node.parse(node_url)
end

# init genesis block
genesis = read_genesis_block("#{__dir__}/genesis.yaml")
puts "read genesis:"
pp genesis.header.inspect

db = DB::Backend::Rocks.new('tmp/test_db')
fork_config = Forks::Config.new([[0, Forks::Frontier], [1150000, Forks::Homestead], [4370000, Forks::Byzantium]])
chain = POWChain::Chain.new(db, genesis: genesis, network_id: 1, fork_config: fork_config)

# init eth protocol
eth_protocol = Eth::EthProtocol.new(name: 'eth', version: 63, length: 17, chain: chain)

# init node
bootnodes = [get_target_node]

# init server
private_key = Ciri::Key.random
server = Ciri::P2P::Server.new(private_key: private_key, protocols: [eth_protocol], bootnodes: bootnodes, tcp_port: 0, udp_port: 0)

puts "start syncing server"

server.run
