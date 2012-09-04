require "anvil"
require "anvil/builder"
require "anvil/engine"
require "anvil/manifest"
require "anvil/version"
require "progress"
require "thor"
require "uri"

class Anvil::CLI < Thor

  map ["-v", "--version"] => :version

  desc "build [SOURCE]", "Build an application"

  method_option :buildpack, :type => :string,  :aliases => "-b", :desc => "Use a specific buildpack"
  method_option :pipeline,  :type => :boolean, :aliases => "-p", :desc => "Pipe compile output to stderr and put the slug url on stdout"

  def build(source=nil)
    Anvil::Engine.build(source, options)
  rescue Anvil::Builder::BuildError => ex
    error "Build Error: #{ex.message}"
  end

  desc "version", "Display Anvil version"

  def version
    Anvil::Engine.version
  end

end
