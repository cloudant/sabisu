#!/usr/bin/env ruby

missing_gems = false
%w(
  rubygems
  rainbow
  rubocop
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

task default: 'test:lint'
task test: ['test:lint']

namespace :test do
  desc 'Run all linting tests (ie rubocop) **default'
  task lint: [:rubocop] do
    if error_detected
      puts 'Failed one or more tests.'.color(:red)
      exit(1)
    else
      puts 'All tests succeeded!'.color(:green)
      exit(0)
    end
  end

  desc 'Run rubocop linting'
  task :rubocop do
    system 'rubocop .'
    error_detected = true if $CHILD_STATUS.exitstatus > 0
    exit(1) if error_detected
  end
end
