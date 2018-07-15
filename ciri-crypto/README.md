# Ciri::Crypto

Crypto module of [Ciri](https://github.com/ciri-ethereum/ciri)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ciri-crypto'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ciri-crypto

## Usage

```ruby
  # signature
  Ciri::Crypto.esdsa_signature(key, data)
  
  # recover
  Ciri::Crypto.ecdsa_recover(msg, signature, return_raw_key: true)
  
  # ecies encrypt
  Ciri::Crypto.ecies_encrypt(message, raw_pubkey, shared_mac_data = '')
  
  # ecies decrypt
  Ciri::Crypto.ecies_encrypt(data, private_key, shared_mac_data = '')
  
  # ensure secp256k1 key 
  Ciri::Crypto.ensure_secp256k1_key(private_key) 
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/ciri-crypto. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](https://opensource.org/licenses/MIT).

## Code of Conduct

Everyone interacting in the Ciri::Crypto project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/ciri-crypto/blob/master/CODE_OF_CONDUCT.md).
