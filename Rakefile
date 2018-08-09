begin
  require "bundler/gem_tasks"
rescue LoadError
  puts "bundler not installed, use 'gem install bundler' to install"
end

begin
  require "rspec/core/rake_task"
  RSpec::Core::RakeTask.new(:spec)
  task :default => :spec
rescue LoadError
  nil
end

desc 'run quick spec'
task :quick do
  exit(1) unless check_env
  run("rspec -t ~slow_tests")
end

desc 'run all specs, include extreme slow tests'
task :"spec:all" do
  exit(1) unless check_env
  run("rspec")
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

  desc 'run quick specs in docker'
  task :quick do
    run("docker run -v `pwd`:/app --rm #{base_image}:latest rake quick")
  end

  desc 'run all specs(include slow tests) in docker'
  task :"spec:all" do
    run("docker run -v `pwd`:/app --rm #{base_image}:latest rake spec:all")
  end

  private

  def default_stack_size
    52428800
  end

  def check_env
    pass = false
    if ENV['RUBY_THREAD_VM_STACK_SIZE'].to_i < default_stack_size
      warn "Ruby stack size is not enough: set env 'RUBY_THREAD_VM_STACK_SIZE' to #{default_stack_size} and try again"
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
