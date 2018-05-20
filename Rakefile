require "bundler/gem_tasks"
require "rspec/core/rake_task"

RSpec::Core::RakeTask.new(:spec)

task :default => :spec

namespace :docker do
  base_image = 'ciriethereum/base'

  desc 'build base docker image'
  task :base do
    system("docker build . -f docker/Base -t #{base_image}:latest")
  end

  desc 'run tests in docker'
  task :test do
    system("docker run --rm #{base_image}:latest rake")
  end
end
