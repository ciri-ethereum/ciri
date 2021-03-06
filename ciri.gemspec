lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ciri/version"

Gem::Specification.new do |spec|
  spec.name = "ciri"
  spec.version = Ciri::VERSION
  spec.authors = ["Jiang Jinyang"]
  spec.email = ["jjyruby@gmail.com"]

  spec.summary = %q{Ciri is an ongoing Ethereum implementation written in Ruby and a blockchain toolbox for all rubyists to build their own chains.}
  spec.description = %q{Ciri is an ongoing Ethereum implementation written in Ruby. Ciri aims to become a researcher-friendly Ethereum implementation and a blockchain toolbox for all developers to modify or build their own private/public chains more conveniently in Ruby.}
  spec.homepage = "https://github.com/ciri-ethereum/ciri"
  spec.license = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) {|f| File.basename(f)}
  spec.require_paths = ["lib"]

  # components
  spec.add_dependency 'ciri-utils', '~> 0.2.2'
  spec.add_dependency 'ciri-rlp', '~> 1.0.1'
  spec.add_dependency 'ciri-crypto', '~> 0.1.1'
  spec.add_dependency 'ciri-common', '~> 0.1.0'
  spec.add_dependency 'ciri-p2p', '~> 0.1.0'

  spec.add_dependency 'ffi', '~> 1.9.23'
  spec.add_dependency 'lru_redux', '~> 1.1.0'
  spec.add_dependency 'bitcoin-secp256k1', '~> 0.4.0'
  spec.add_dependency 'concurrent-ruby', '~> 1.0.5'
  spec.add_dependency 'async', '~> 1.10.3'
  spec.add_dependency 'async-io', '~> 1.15.5'
  spec.add_dependency 'ethash', '~> 0.2.0'
  spec.add_dependency 'snappy', '~> 0.0.17'

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec", "~> 3.8"
  spec.add_development_dependency "parallel_tests", "~> 2.28"
end
