# -*- encoding: utf-8 -*-
require File.expand_path('../lib/jsonrpc2/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Geoff Youngs"]
  gem.email         = ["git@intersect-uk.co.uk"]
  gem.description   = %q{TODO: Write a gem description}
  gem.summary       = %q{JSON-RPC2 server implementation}
  gem.homepage      = ""

  gem.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "jsonrpc2"
  gem.require_paths = ["lib"]
  gem.version       = JSONRPC2::VERSION
  gem.add_dependency("httpclient")
  gem.add_dependency("json")
  gem.add_development_dependency("RedCloth")
end
