# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'pg/logical_replication/version'

Gem::Specification.new do |spec|
  spec.name          = "pg-logical_replication"
  spec.version       = PG::LogicalReplication::VERSION
  spec.authors       = ["Nick Carboni"]
  spec.email         = ["ncarboni@redhat.com"]

  spec.summary       = "A ruby gem for configuring and using postgresql logical replication"
  spec.description   = <<-EOS
This gem provides a class with methods which map directly to the PostgreSQL DSL for logical replication configuration
  EOS
  spec.homepage      = "https://github.com/ManageIQ/pg-logical_replication"
  spec.license       = "Apache-2.0"

  spec.files         = `git ls-files -z`.split("\x0").reject { |f| f.match(%r{^(test|spec|features)/}) }
  spec.bindir        = "exe"
  spec.executables   = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = ["lib"]

  spec.add_dependency "pg"

  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec", "~> 3.0"
  spec.add_development_dependency "rubocop", "~> 0.52"
  spec.add_development_dependency "simplecov"
end
