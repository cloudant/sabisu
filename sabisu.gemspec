require File.expand_path('../lib/sabisu/version', __FILE__)

docs = %w( LICENSE README.md )

Gem::Specification.new do |s|
  s.name        = 'sabisu'
  s.version     = Sabisu::VERSION
  s.date        = Time.now.strftime('%F')
  s.summary     = 'A sensu dashboard powered by Cloudant'
  s.description = 'Sabisu is a dashboard for the monitoring framework Sensu. ' \
                  'It is powered by Cloudant to give strong features like fast ' \
                  'performance, full text search, and more.'
  s.authors     = ['Chad Barraford', 'Matthew White']
  s.email       = 'chad@cloudant.com'
  s.extra_rdoc_files = docs
  s.files       = docs + Dir.glob('{lib,bin}/**/*', File::FNM_DOTMATCH).reject do |f|
    File.directory?(f)
  end
  s.executables = `git ls-files -- bin/*`.split("\n").map { |f| File.basename(f) }
  s.homepage    = 'http://sabisuapp.org'
  s.license     = 'Apache License v2'
  s.required_ruby_version = '>= 2.0.0'

  s.add_dependency 'sinatra', '~> 1.4.4'
  %w( thin haml couchrest rack-ssl-enforcer ).each do |gem|
    s.add_dependency gem
  end
end
