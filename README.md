Ethruby
===============

Ethruby project intent to implement full feature set of ethereum in pure ruby, to provide both usable cli and well documented ruby library.

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
gem install ethruby
```

As library

``` ruby
require 'ethruby'
puts ETH::Version
```

### Command line

`eth -h`

### Documentation

[YARD documentation](https://www.rubydoc.info/github/ruby-ethereum/ethereum/master)

### Author

[Jiang Jinyang](https://justjjy.com)
