#!/usr/bin/env ruby

missing_gems = false
%w(
  rubygems
  rainbow
  rubocop
  haml_lint
  bundler/gem_tasks
).each do |gem|
  begin
    require gem
  rescue Gem::LoadError
    puts "Unable to load #{gem} gem, please install it (`gem install #{gem}`)"
    missing_gems = true
  end
end
exit(2) if missing_gems

error_detected = false
basedir = File.dirname(__FILE__)

task default: 'lint:all'
task lint: ['lint:all']

namespace :lint do
  desc 'Run all linting tests **default'
  task all: [:ruby, :haml] do
    if error_detected
      puts 'Failed one or more tests.'.color(:red)
      exit(1)
    else
      puts 'All tests succeeded!'.color(:green)
      exit(0)
    end
  end

  desc 'Lint Ruby (using rubocop)'
  task :ruby do
    puts 'Linting Ruby files'.color(:magenta)
    paths = %w(Rakefile lib/ bin/ sensu-integration/)
    paths = paths.map { |f| File.join(basedir, f) }
    system "rubocop #{paths.join(' ')}"
    error_detected = true if $CHILD_STATUS.exitstatus > 0
    print "\n\n"
  end

  desc 'Lint HAML (using haml-lint)'
  task :haml do
    puts 'Linting HAML files'.color(:magenta)
    system "haml-lint #{basedir}/lib/sabisu/templates/"
    error_detected = true if $CHILD_STATUS.exitstatus > 0
    print "\n\n"
  end
end
