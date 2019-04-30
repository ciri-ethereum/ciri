require "bundler/gem_tasks"
require 'fileutils'
require 'tmpdir'

begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
  task :default => :spec
rescue LoadError
  warn("rspec not installed, use `gem install rspec-core` to install")
end

namespace :install do
  desc "Build and install secp256k1 shared library"
  task :secp256k1 do
    Dir.mktmpdir do |path|
      source_dir = "secp256k1"
      build_dir = "#{path}/#{source_dir}"
      FileUtils.copy_entry source_dir, build_dir
      Dir.chdir(build_dir)
      run("./autogen.sh")
      run("./configure --enable-module-recovery --enable-experimental --enable-module-ecdh")
      run("make")
      run("make install")
    end
    puts "Success installed secp256k1"
  end

  desc "Build and install all"
  task all: [:secp256k1, :install]
end

namespace :docker do
  base_image = 'ciriethereum/ciri-p2p-test'

  desc 'pull docker image'
  task :pull do
    run("docker pull #{base_image}:latest")
  end

  desc 'build docker image, rerun this task after updated Gemfile or Dockerfile'
  task :build do
    system("git submodule init && git submodule update")
    run("docker build . -f Dockerfile -t #{base_image}:latest")
  end

  desc 'push docker image'
  task :push do
    run("docker push #{base_image}:latest")
  end

  desc 'open Ciri P2P develop container shell'
  task :shell do
    container_name = 'ciri-p2p-develop'
    if system("docker inspect #{container_name} > /dev/null")
      system("docker start -i #{container_name}")
    else
      puts "start a new develop container: #{container_name}"
      system("docker run -v `pwd`:/app -it --name #{container_name} #{base_image}:latest bash")
    end
  end

  desc 'run spec in docker'
  task :spec do |task, args|
    run("docker run -v `pwd`:/app --rm #{base_image}:latest rake")
  end
end

private

def run(cmd)
  puts "$ #{cmd}"
  pid = spawn(cmd)
  Process.wait(pid)
  exit $?.exitstatus unless $?.success?
end

