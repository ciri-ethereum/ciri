lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ciri/version"

Gem::Specification.new do |spec|
  spec.name = "ciri"
  spec.version = Ciri::VERSION
  spec.authors = ["Jiang Jinyang"]
  spec.email = ["jjyruby@gmail.com"]

  spec.summary = %q{Ciri ethereum client.}
  spec.description = %q{Ciri project intent to implement a full feature set ethereum client.}
  spec.homepage = "https://github.com/ciri-ethereum/ciri"
  spec.license = "MIT"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) {|f| File.basename(f)}
  spec.require_paths = ["lib"]

  spec.add_dependency 'digest-sha3', '~> 1.1.0'
  spec.add_dependency 'bitcoin-secp256k1', '~> 0.4.0'
  spec.add_dependency 'concurrent-ruby', '~> 1.0.5'
  spec.add_dependency 'snappy', '~> 0.0.17'
  spec.add_dependency 'rocksdb-ruby2', '~>0.1.4'

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
