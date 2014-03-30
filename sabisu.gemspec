require File.expand_path('../lib/sabisu/version', __FILE__)

docs = %w( LICENSE README.md )

Gem::Specification.new do |s|
  s.name        = 'sabisu'
  s.version     = Sabisu::VERSION
  s.date        = Time.now.strftime('%F')
  s.summary     = 'A sensu dashboard powered by Cloudant'
  s.description = 'Sabisu is a dashboard for the monitoring framework Sensu. ' \
                  'It is powered by Cloudant to provide strong features such as ' \
                  'full text search and fast performance.'
  s.authors     = ['Chad Barraford', 'Matt White']
  s.email       = 'chad@cloudant.com'
  s.extra_rdoc_files = docs
  s.files       = docs +
                  Dir.glob('{lib,bin}/**/*', File::FNM_DOTMATCH).reject do |f|
                    File.directory?(f)
                  end
  s.executables = %x{git ls-files -- bin/*}.split("\n").map { |f| File.basename(f) }
  s.homepage    = 'http://sabisuapp.org'
  s.license     = 'Apache License v2'
  s.required_ruby_version = '>= 2.0.0'

  # runtime dependencies
  s.add_dependency 'sinatra', '~> 1.4.4'
  %w( thin haml couchrest restclient rack-ssl-enforcer json ).each do |gem|
    s.add_dependency gem
  end

  # development dependencies
  s.add_development_dependency 'rubocop', '>=0.19.1'
  %w( rake heroku foreman racksh coffeelint haml-lint ).each do |gem|
    s.add_development_dependency gem
  end
end
