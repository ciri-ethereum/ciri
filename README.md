Ciri
===============
[![Build Status](https://travis-ci.org/ciri-ethereum/ciri.svg?branch=master)](https://travis-ci.org/ciri-ethereum/ciri)
[![Gitter](https://badges.gitter.im/join.svg)](https://gitter.im/ciri-ethereum/Lobby)

Ciri ethereum is intended to build as a full feature set ethereum implementation.

It aims to be a feature complete, long maintained and stable ethereum implementation.
As you see it'is still under development.

Talk to me on [gitter](https://gitter.im/ciri-ethereum/Lobby) if you interesting in this project or want to contributing. See [How to learn Ethereum and contibute to Ciri](https://github.com/ciri-ethereum/ciri/wiki#how-to-learn-ethereum-and-contribute-to-ciri).

See [projects](https://github.com/ciri-ethereum/ciri/projects) and [milestones](https://github.com/ciri-ethereum/ciri/milestones) for current development status.

Roadmap
---------------

See [Wiki Roadmap](https://github.com/ciri-ethereum/ciri/wiki)

Documentation
---------------

[YARD documentation](https://www.rubydoc.info/github/ciri-ethereum/ciri/master)

Development
---------------

Ciri depends on [rocksdb](https://github.com/facebook/rocksdb), [secp256k1](https://github.com/bitcoin-core/secp256k1), [ethash](https://github.com/ethereum/ethash) and [snappy](https://github.com/google/snappy).

It's recommendation to [setup with docker](#setup-with-docker), it will save lots of time.


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
RUBY_THREAD_VM_STACK_SIZE=52428800 bundle exec rake test
```


### Setup with docker

It's recommendation to use docker to handle dependencies:

make sure we have installed docker, ruby and rake
``` bash
# make sure we have installed docker, ruby and rake
docker -v
gem install rake
```

#### Pull docker image
pull latest released Ciri docker image
``` bash
# pull Ciri docker image
rake docker:pull
```

#### Build docker image
build local docker image (it will take few minutes)
``` bash
# build Ciri docker image
rake docker:build
```

#### Run tests in docker
``` bash
# run tests
rake docker:test
```

#### Other usage
``` bash
# open a shell for develop
rake docker:shell

# cool, type 'rake -T' see other supported tasks 
rake -T
``` 

Contributors
---------------

See [Contributors](https://github.com/ciri-ethereum/ciri/graphs/contributors)
