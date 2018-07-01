
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "ciri/rlp/version"

Gem::Specification.new do |spec|
  spec.name          = "ciri-rlp"
  spec.version       = Ciri::RLP::VERSION
  spec.authors       = ["Jiang Jinyang"]
  spec.email         = ["jjyruby@gmail.com"]

  spec.summary       = %q{The RLP serialization library.}
  spec.description   = %q{Provide simple and structure RLP serialization.}
  spec.homepage      = "https://github.com/ciri-ethereum/ciri"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "ciri-utils", "~> 0.1.0"
  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
