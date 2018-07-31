# Ciri::RLP

The Ruby RLP serialization library.

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'ciri-rlp'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install ciri-rlp

## Usage

Simple use:

```ruby
# encode
Ciri::RLP.encode(3)
Ciri::RLP.encode(["cat", 1, "dog", 3])
# decode
Ciri::RLP.decode("rlp encoded content")
```

Structure:
```ruby
# declare a RLP structure
class Doge
  include Ciri::RLP::Serializable
  
  # RLP is a low level encoding format, only support string(bytes) and list.
  # so we use a list to present structure data
  # we also need to declare column type clearly if column is not string
  schema [
    :name,
    {age: Integer}, # declare age is a Integer type
    :gender,
    {has_master: Ciri::RLP::Bool} # dechare bool
  ]
end

doge = Doge.new(name: 'neo doge', age: 5, gender: "boy", has_master: false)
# use auto generated encode method
encoded = Doge.rlp_encode(doge)
Doge.rlp_decode(encoded) == doge 
# => true
```

Customize:
```ruby
class DogeList
  attr_reader :doges
  
  def initialize(doges)
    @doges = doges
  end
  
  # provide two class methods: rlp_encode and rlp_decode to customize RLP behaviour
  # ciri-rlp will consider duck-typing and invoke those methods 
  # customize RLP class can be member of other RLP struct
  def self.rlp_encode(doge_list)
    # [Doge] represent the encode data is an array of Doge 
    Ciri::RLP.encode(doge_list.doges, [Doge])
  end
  
  def self.rlp_decode(encoded)
    doges = Ciri::RLP.decode(encoded, [Doge])
    DogeList.new(doges)
  end
end

```

## Development

After checking out the repo, run `bin/setup` to install dependencies. Then, run `rake spec` to run the tests. You can also run `bin/console` for an interactive prompt that will allow you to experiment.

To install this gem onto your local machine, run `bundle exec rake install`. To release a new version, update the version number in `version.rb`, and then run `bundle exec rake release`, which will create a git tag for the version, push git commits and tags, and push the `.gem` file to [rubygems.org](https://rubygems.org).

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/[USERNAME]/ciri-rlp. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [Apache License Version 2.0](http://www.apache.org/licenses/).

## Code of Conduct

Everyone interacting in the Ciri::Rlp project’s codebases, issue trackers, chat rooms and mailing lists is expected to follow the [code of conduct](https://github.com/[USERNAME]/ciri-rlp/blob/master/CODE_OF_CONDUCT.md).
