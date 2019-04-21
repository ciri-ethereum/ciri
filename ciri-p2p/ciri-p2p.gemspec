
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ciri/p2p/version"

Gem::Specification.new do |spec|
  spec.name          = "ciri-p2p"
  spec.version       = Ciri::P2P::VERSION
  spec.authors       = ["jjy"]
  spec.email         = ["jjyruby@gmail.com"]

  spec.summary       = %q{P2P network implementation for Ciri Ethereum.}
  spec.description   = %q{ciri-p2p is a DevP2P implementation, we also seek to implement LibP2P components upon ciri-p2p codebase in the future.}
  spec.homepage      = "https://github.com/ciri-ethereum/ciri-p2p"
  spec.license       = "MIT"

  # Specify which files should be added to the gem when it is released.
  # The `git ls-files -z` loads the files in the RubyGem that have been added into git.
  spec.files         = Dir.chdir(File.expand_path('..', __FILE__)) do
    `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'ciri-utils', '~> 0.2.2'
  spec.add_dependency 'ciri-rlp', '~> 1.0.1'
  spec.add_dependency 'ciri-crypto', '~> 0.1.1'
  spec.add_dependency 'ciri-common', '~> 0.1.0'
  spec.add_dependency 'async', '~> 1.10.3'
  spec.add_dependency 'async-io', '~> 1.15.5'
  spec.add_dependency 'snappy', '~> 0.0.17'

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
