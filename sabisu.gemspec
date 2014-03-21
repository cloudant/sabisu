require File.expand_path("../lib/sabisu/version", __FILE__)

Gem::Specification.new do |s|
  s.name        = 'sabisu'
  s.version     = Sabisu::VERSION
  s.date        = Time.now().strftime('%F')
  s.summary     = 'A sensu dashboard powered by Cloudant'
  s.description = 'Sabisu is a dashboard for the monitoring framework Sensu. It is powered by Cloudant to give strong features like fast performance, full text search, and more.'
  s.authors     = ["Chad Barraford", "Matthew White"]
  s.email       = 'chad@cloudant.com'
  s.files       = `git ls-files`.split("\n").keep_if do |f|
    f =~ /^(bin\/|lib\/|LICENSE|README.md|config.ru|Procfile|Gemfile)/
  end
  s.executables = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.homepage    = 'http://sabisuapp.org'
  s.license     = 'Apache License v2'
  s.add_runtime_dependency "sinatra"
  s.add_runtime_dependency "redis"
  s.add_runtime_dependency "couchrest"
  s.required_ruby_version = '>= 2.0.0'
end
