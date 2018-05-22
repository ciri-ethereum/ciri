Ciri
===============
[![Build Status](https://travis-ci.org/ciri-ethereum/ciri.svg?branch=master)](https://travis-ci.org/ciri-ethereum/ciri)
[![Gitter](https://badges.gitter.im/join.svg)](https://gitter.im/ciri-ethereum/Lobby)

Ciri project intent to implement a full feature set ethereum client.

Check List
---------------

* [ ] RLPX
  * [x] HandShake
  * [ ] Server
  * [ ] Node Discovery
* [x] RLP
* [ ] Eth Protocol
  * [x] HandShake
  * [ ] Ethereum Sub-protocol
* [ ] Block Chain
  * [ ] Chain Syncing
  * [ ] EVM
  * [ ] Mining
* [ ] Consensus Algorithm
  * [ ] POW
  * [ ] POS
* [ ] Web3 RPC
* [ ] CLI

Installation
---------------

``` bash
gem install ciri
```

Usage
---------------

`ciri -h`

Develop
---------------

Ciri depends on [rocksdb](https://github.com/facebook/rocksdb), [secp256k1](https://github.com/bitcoin-core/secp256k1) and [snappy](https://github.com/google/snappy).

It's recommended to use docker to handle dependencies:
``` bash
# make sure we have installed docker, ruby and rake
docker -v
gem install rake

# pull Ciri base image
rake docker:pull_base
# run tests
rake docker:test
# open a shell for develop
rake docker:shell

# cool, type 'rake -T' see other supported tasks 
``` 
Check [docker](/docker) directory for docker-files.
 
Otherwise you need install these libraries first (remember check [docker](/docker) directory for hint).

then run: 
`bundle install && bundle exec rake`

Documentation
---------------

[YARD documentation](https://www.rubydoc.info/github/ciri-ethereum/ciri/master)

Authors
---------------

* [Jiang Jinyang](https://justjjy.com) <jjyruby@gmail.com>
