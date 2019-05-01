require 'ciri'
require 'ciri/pow_chain/transaction'
require 'ciri/key'
require 'ciri/utils'

include Ciri

transaction = POWChain::Transaction.new(
  nonce: 1,
  gas_price: 10,
  gas_limit: 21000,
  to: "\x00".b * 20,
  value: 10 ** 18
)

# generate sender priv_key
priv_key = Key.random
# sign transaction
transaction.sign_with_key!(priv_key)

sender = Utils.hex(transaction.sender)
puts "#{sender}\n-> send #{transaction.value} to\n#{Utils.hex transaction.to}"
