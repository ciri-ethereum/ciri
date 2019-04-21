# Ciri::P2P 
[![Build Status](https://travis-ci.org/ciri-ethereum/ciri-p2p.svg?branch=master)](https://travis-ci.org/ciri-ethereum/ciri-p2p)

P2P network implementation for [Ciri Ethereum](https://github.com/ciri-ethereum/ciri).

`ciri-p2p` is a [DevP2P](https://github.com/ethereum/devp2p) implementation, we also seek to implement [LibP2P](https://github.com/libp2p/libp2p) components upon ciri-p2p codebase in the future.

## Installation

### Install dependencies

Ciri P2P depend on `secp256k1` to handle crypto signature and depend on `snappy` to compress data.

Build and install `secp256k1`

``` bash
cd ciri
git submodule init && git submodule update
rake install:secp256k1
```

On Mac you can install `snappy` with homebrew

``` bash
brew install snappy
```

For linux users, remember to check [Dockerfile](/docker) instructions for hint.

then run tests: 
``` bash
bundle exec rake spec
```

### Install as Gem

Add this line to your application's Gemfile:

```ruby
gem 'ciri-p2p'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ciri-p2p

## Usage

Check [spec](https://github.com/ciri-ethereum/ciri-p2p/tree/master/spec) directory, especially [server_spec.rb](https://github.com/ciri-ethereum/ciri-p2p/blob/master/spec/ciri/p2p/server_spec.rb).

#### Examples

* [3 nodes connected each other](https://github.com/ciri-ethereum/ciri-p2p/blob/master/spec/ciri/p2p/server_spec.rb#L106)
* [Gossip DNS Example](https://github.com/jjyr/gossip-dns-example)

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/ciri-ethereum/ciri-p2p. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Ciri::P2p project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/ciri-p2p/blob/master/CODE_OF_CONDUCT.md).

