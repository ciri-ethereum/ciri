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
  Ciri::Crypto.esdsa_signature("\x00...(privkey)", "\x00...(data)")
  
  # recover
  Ciri::Crypto.ecdsa_recover("I\x90...(signed hash)", "f\xAA...(signature)", return_raw_key: true)
  
  # ecies encrypt
  key = OpenSSL::PKey::EC.new('secp256k1')
  key.generate_key 
  encrypt_data = Ciri::Crypto.ecies_encrypt("hello ciri", key, shared_mac_data = '')
  
  # ecies decrypt
  Ciri::Crypto.ecies_decrypt(encrypt_data, key, shared_mac_data = '')
  
  # ensure secp256k1 key 
  Ciri::Crypto.ensure_secp256k1_key(privkey: "\x00...") 
```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/ciri-crypto. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [Apache License Version 2.0](http://www.apache.org/licenses/).

## Code of Conduct

Everyone interacting in the Ciri::Crypto project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/ciri-crypto/blob/master/CODE_OF_CONDUCT.md).
