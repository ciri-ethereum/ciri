Ciri
===============
[![Build Status](https://travis-ci.org/ciri-ethereum/ciri.svg?branch=master)](https://travis-ci.org/ciri-ethereum/ciri)
[![Gitter](https://badges.gitter.im/join.svg)](https://gitter.im/ciri-ethereum/Lobby)

Ciri is an ongoing Ethereum implementation.

It aims to be a feature complete Ethereum implementation and expects to achieve both research-friendly and high-performance.
As you see it's still under development.

See [How to learn Ethereum and contribute to Ciri](https://github.com/ciri-ethereum/ciri/wiki#how-to-learn-ethereum-and-contribute-to-ciri).

See [projects](https://github.com/ciri-ethereum/ciri/projects) and [milestones](https://github.com/ciri-ethereum/ciri/milestones) for current development status.

Roadmap
---------------

See [Roadmap](https://github.com/ciri-ethereum/ciri/wiki)  on Wiki

Development
---------------

Ciri depends on [rocksdb](https://github.com/facebook/rocksdb), [secp256k1](https://github.com/bitcoin-core/secp256k1), [ethash](https://github.com/ethereum/ethash) and [snappy](https://github.com/google/snappy).

It's recommendation to [setup with docker](#setup-with-docker), it will save lots of time.

### Setup with docker

Use docker command to pull image:

``` bash
docker pull ciriethereum/ciri
```

Or you can use our prepared rake tasks if you not familiar with docker:

clone repo and submodules

``` bash
git clone --recursive https://github.com/ciri-ethereum/ciri.git
cd ciri
```

make sure we have installed docker, ruby and rake
``` bash
# make sure we have installed docker, ruby and rake
docker -v
gem install rake
```

#### Pull docker image

``` bash
# pull Ciri docker image
rake docker:pull
```

#### Build docker image
(it will take few minutes)
``` bash
# build Ciri docker image
rake docker:build
```

#### Run tests in docker
``` bash
# run tests
rake docker:quick
```

#### Other usage
``` bash
# open a shell for develop
rake docker:shell

# type 'rake -T' see other supported tasks 
rake -T
``` 

### Manually Setup

clone repo and submodules

``` bash
git clone --recursive https://github.com/ciri-ethereum/ciri.git
```

#### Install dependencies

On mac you can install `rocksdb` and `snappy` with homebrew

``` bash
brew install rocksdb snappy
```

then manually install

ethash
``` bash
cd ethash/src/libethash && cmake CMakeLists.txt && make install
```

secp256k1
``` bash
cd secp256k1 && ./autogen.sh && ./configure --enable-module-recovery --enable-experimental --enable-module-ecdh && make && make install
```

For linux user, remember check [Dockerfile](/docker) instructions for hint.

then run: 
``` bash
bundle install
```

run tests:
``` bash
RUBY_THREAD_VM_STACK_SIZE=52428800 bundle exec rake quick
```

Why Ruby?
---------------

Ruby is awesome, Ethereum is awesome too, so tell me a reason why not to use Ruby to implement Ethereum?

Seriously, 

Ruby is a scripting language, it's easy to write prototype or research code with Ruby (like the official python Ethereum implementation intended).

And with the several performance research projects in Ruby community (JIT, JRuby, TruffleRuby), we can expect the language performance improve in the future.

So with Ruby, we can expect to achieve both research-friendly and high-performance in our implementation.


Contributors
---------------

See [Contributors](https://github.com/ciri-ethereum/ciri/graphs/contributors)
