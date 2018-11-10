begin
  require "bundler/gem_tasks"
rescue LoadError
  puts "bundler not installed, use 'gem install bundler' to install"
end

require 'fileutils'
require 'tmpdir'

task :default => :spec

desc 'run spec, use argument to specific a component, default will skip slow tests'
task :spec, [:component, :skip_slow] do |task, args|
  exit(1) unless check_env
  cli = "rspec"
  if args.fetch(:skip_slow, true)
    cli += " -t ~slow_tests"
  end
  if (component = args[:component])
    cli += " spec/ciri/#{component}"
  else
    warn("Run all test cases... maybe slow")
  end
  run(cli)
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
  base_image = 'ciriethereum/ciri'

  desc 'pull docker image'
  task :pull do
    run("docker pull #{base_image}:latest")
  end

  desc 'build docker image, rerun this task after updated Gemfile or Dockerfile'
  task :build do
    system("git submodule init && git submodule update")
    run("docker build . -f docker/Dockerfile -t #{base_image}:latest")
  end

  desc 'push docker image'
  task :push do
    run("docker push #{base_image}:latest")
  end

  desc 'open Ciri develop container shell'
  task :shell do
    container_name = 'ciri-develop'
    if system("docker inspect #{container_name} > /dev/null")
      system("docker start -i #{container_name}")
    else
      puts "start a new develop container: #{container_name}"
      system("docker run -v `pwd`:/app -it --name #{container_name} #{base_image}:latest bash")
    end
  end

  desc 'run spec in docker'
  task :spec, [:component, :skip_slow] do |task, args|
    cli_args = ""
    args_hash = args.to_h
    unless args_hash.empty?
      cli_args = "[#{args_hash.values.join(", ")}]"
    end
    run("docker run -v `pwd`:/app --rm #{base_image}:latest rake 'spec#{cli_args}'")
  end

  private

  def default_stack_size
    52428800
  end

  def check_env
    pass = false
    if ENV['RUBY_THREAD_VM_STACK_SIZE'].to_i < default_stack_size
      warn "Ruby stack size is not enough: set env 'RUBY_THREAD_VM_STACK_SIZE' to #{default_stack_size} and try again, otherwise you may failed to pass EVM related tests"
      warn "export RUBY_THREAD_VM_STACK_SIZE=#{default_stack_size}"
    else
      pass = true
    end
    pass
  end

  def default_env
    {'RUBY_THREAD_VM_STACK_SIZE' => ENV['RUBY_THREAD_VM_STACK_SIZE'] || default_stack_size.to_s}
  end
end

private

def run(cmd)
  puts "$ #{cmd}"
  pid = spawn(cmd)
  Process.wait(pid)
  exit $?.exitstatus unless $?.success?
end
