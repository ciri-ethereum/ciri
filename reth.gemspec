
lib = File.expand_path("../lib", __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require "reth/version"

Gem::Specification.new do |spec|
  spec.name          = "reth"
  spec.version       = Reth::VERSION
  spec.authors       = ["Jiang Jinyang"]
  spec.email         = ["jjyruby@gmail.com"]

  spec.summary       = %q{Ruby implemented ethereum}
  spec.description   = %q{Reth's intention is to implement a full feature set ethereum. Provide both ethereum cli and ruby library.}
  spec.homepage      = "https://github.com/ruby-ethereum/ethereum"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0").reject do |f|
    f.match(%r{^(test|spec|features)/})
  end
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_development_dependency "bundler", "~> 1.16"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
end
