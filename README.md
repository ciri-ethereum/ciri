Ciri
===============
[![Build Status](https://travis-ci.org/ruby-ethereum/ciri.svg?branch=master)](https://travis-ci.org/ruby-ethereum/ciri)
[![Gitter](https://badges.gitter.im/join.svg)](https://gitter.im/ciri-ethereum/Lobby)

Ciri project intent to implement a full feature set ethereum client.

### Check List

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

### Install

``` bash
gem install ciri
```

As library

``` ruby
require 'ciri'
puts Ciri::Version
```

### Command line

`ciri -h`

### Documentation

[YARD documentation](https://www.rubydoc.info/github/ruby-ethereum/ciri/master)

### Author

[Jiang Jinyang](https://justjjy.com)
