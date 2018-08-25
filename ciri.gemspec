lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ciri/version"

Gem::Specification.new do |spec|
  spec.name = "ciri"
  spec.version = Ciri::VERSION
  spec.authors = ["Jiang Jinyang"]
  spec.email = ["jjyruby@gmail.com"]

  spec.summary = %q{Ciri is an ongoing Ethereum implementation.}
  spec.description = %q{It aims to be a feature complete Ethereum implementation and expects to achieve both research-friendly and high-performance.}
  spec.homepage = "https://github.com/ciri-ethereum/ciri"
  spec.license = "Apache 2.0"

  spec.files = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir = "exe"
  spec.executables = spec.files.grep(%r{^exe/}) {|f| File.basename(f)}
  spec.require_paths = ["lib"]

  # components
  spec.add_dependency 'ciri-utils', '~> 0.2.1'
  spec.add_dependency 'ciri-rlp', '~> 1.0.0'
  spec.add_dependency 'ciri-crypto', '~> 0.1.1'

  spec.add_dependency 'ffi', '~> 1.9.23'
  spec.add_dependency 'lru_redux', '~> 1.1.0'
  spec.add_dependency 'bitcoin-secp256k1', '~> 0.4.0'
  spec.add_dependency 'concurrent-ruby', '~> 1.0.5'
  spec.add_dependency 'snappy', '~> 0.0.17'

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
