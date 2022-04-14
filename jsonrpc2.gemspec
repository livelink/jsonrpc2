# -*- encoding: utf-8 -*-
require File.expand_path('../lib/jsonrpc2/version', __FILE__)

Gem::Specification.new do |gem|
  gem.authors       = ["Geoff Youngs"]
  gem.email         = ["git@intersect-uk.co.uk"]
  gem.description   = <<-EOD
== Description

A Rack compatible JSON-RPC2 server domain specific language (DSL) - allows JSONRPC APIs to be
defined as mountable Rack applications with inline documentation, authentication and type checking.

e.g.

  class Calculator < JSONRPC2::Interface
    title "JSON-RPC2 Calculator"
    introduction "This interface allows basic maths calculations via JSON-RPC2"
    auth_with JSONRPC2::BasicAuth.new({'user' => 'secretword'})

    section 'Simple Ops' do
        desc 'Multiply two numbers'
        param 'a', 'Number', 'a'
        param 'b', 'Number', 'b'
        result 'Number', 'a * b'
        def mul args
          args['a'] * args['b']
        end

        desc 'Add numbers'
        example "Calculate 1 + 1 = 2", :params => { 'a' => 1, 'b' => 1}, :result => 2

        param 'a', 'Number', 'First number'
        param 'b', 'Number', 'Second number'
        optional 'c', 'Number', 'Third number'
        result 'Number', 'a + b + c'
        def sum args
          val = args['a'] + args['b']
          val += args['c'] if args['c']
          val
        end
    end
  end

EOD
  gem.summary       = %q{JSON-RPC2 server DSL}
  gem.homepage      = "http://github.com/livelink/jsonrpc2"

  gem.bindir        = 'exe'
  gem.executables   = `git ls-files -- exe/*`.split("\n").map{ |f| File.basename(f) }
  gem.files         = `git ls-files`.split("\n")
  gem.test_files    = `git ls-files -- {test,spec,features}/*`.split("\n")
  gem.name          = "jsonrpc2"
  gem.require_paths = ["lib"]
  gem.version       = JSONRPC2::VERSION
  gem.metadata = {
    "bug_tracker_uri"   => "https://github.com/livelink/jsonrpc2/issues",
    "changelog_uri"     => "https://github.com/livelink/jsonrpc2/blob/master/CHANGELOG.md",
    "documentation_uri" => "https://github.com/livelink/jsonrpc2#inline-documentation",
  }

  gem.add_dependency("httpclient")
  gem.add_dependency("json")
  gem.add_dependency("RedCloth")
  gem.add_dependency('thor')

  gem.add_development_dependency('rack') # Makes it possible to test JSONRPC2::Interface
  gem.add_development_dependency('rspec')
  gem.add_development_dependency('puma') # Required to run rackup example/config.ru
  gem.add_development_dependency('pry-byebug')
end
