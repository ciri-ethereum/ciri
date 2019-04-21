require "bundler/setup"
require "ciri/p2p"

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
  # set logger
  require 'ciri/utils/logger'
  level = %w{1 yes true}.include?(ENV['DEBUG']) ? :debug : :fatal
  Ciri::Utils::Logger.setup(level: level)
end
