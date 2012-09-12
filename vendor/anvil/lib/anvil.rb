require "anvil/version"

module Anvil

  def self.agent
    @@agent ||= "anvil-cli/#{Anvil::VERSION}"
  end

  def self.append_agent(str)
    @@agent = self.agent + " " + str
  end

  def self.headers
    @headers ||= {}
  end

end
