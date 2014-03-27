#!/usr/bin/env ruby

missing_gems = false
%w(
  rubygems
  rainbow
  rubocop
  haml_lint
  coffeelint
  json
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

def valid_json?(path)
  JSON.parse(File.read(path))
  true
rescue JSON::ParserError
  false
end

task default: 'lint:all'
task lint: ['lint:all']

namespace :lint do
  desc 'Run all linting tests **default'
  task all: [:json, :ruby, :coffeescript, :haml] do
    if error_detected
      puts 'Failed one or more tests.'.color(:red)
      exit(1)
    else
      puts 'All tests succeeded!'.color(:green)
      exit(0)
    end
  end

  desc 'Lint JSON'
  task :json do
    puts 'Linting JSON files'.color(:magenta)
    Dir[File.join(basedir, '**', '*.json')].each do |path|
      next if path.include?('.example')

      print "#{path}... "
      if valid_json?(path)
        puts 'OK'.color(:green)
      else
        puts 'FAILED'.color(:red)
        error_detected = true
      end
    end
    print "\n\n"
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

  desc 'Lint CoffeeScript (using coffeelint)'
  task :coffeescript do
    puts 'Linting CoffeeScript files'.color(:magenta)
    system "coffeelint.rb -f #{basedir}/.coffeelint.json -r #{basedir}/lib/sabisu/public/"
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
