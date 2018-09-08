Sync Block
-----------

##### 1. Start geth/parity client:

`geth --nodiscover --verbosity 5 console`

##### 2. Copy node_id from output:

`da982df3c882252c126ac3ee8fa008ade932c4166dfdc7c117c9852b5df0c6ddcf34bf2555a38596268b3b6bcbdaf48bba57b84a1abc400b4ba65c59ee5342c3`

##### 3. Run `sync.rb` to start syncing blocks from node:

`ruby -Ilib examples/sync_blocks/sync.rb <node_id>`

Blocks will be saved in `tmp/test_db`
