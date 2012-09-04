$:.unshift File.expand_path("../lib", __FILE__)
require "anvil/version"

Gem::Specification.new do |gem|
  gem.name     = "anvil-cli"
  gem.version  = Anvil::VERSION

  gem.author   = "David Dollar"
  gem.email    = "david@dollar.io"
  gem.homepage = "http://github.com/ddollar/anvil-cli"
  gem.summary  = "Alternate Heroku build workflow"

  gem.description = gem.summary

  gem.executables = "anvil"
  gem.files = Dir["**/*"].select { |d| d =~ %r{^(README|bin/|data/|ext/|lib/|spec/|test/)} }

  gem.add_dependency "progress",    "~> 2.4.0"
  gem.add_dependency "rest-client", "~> 1.6.7"
  gem.add_dependency "thor",        "~> 0.15.2"
end
