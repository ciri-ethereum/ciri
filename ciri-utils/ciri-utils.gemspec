
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ciri/utils/version"

Gem::Specification.new do |spec|
  spec.name          = "ciri-utils"
  spec.version       = Ciri::Utils::VERSION
  spec.authors       = ["Jiang Jinyang"]
  spec.email         = ["jjyruby@gmail.com"]

  spec.summary       = %q{Toolkit module of [Ciri](https://github.com/ciri-ethereum/ciri)}
  spec.description   = %q{Functions include: big endian encode/decode, hex/bytes convert, keccak256 ...}
  spec.homepage      = "https://github.com/ciri-ethereum/ciri-utils"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency 'digest-sha3', '~> 1.1.0'
  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 12.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
