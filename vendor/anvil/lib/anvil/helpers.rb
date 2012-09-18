require "anvil"
require "anvil/okjson"

module Anvil::Helpers

  def json_encode(obj)
    Anvil::OkJson.encode(obj)
  end

  def json_decode(str)
    Anvil::OkJson.decode(str)
  end

  def anvil_metadata_dir(root)
    dir = File.join(root, ".anvil")
    FileUtils.mkdir_p(dir)
    dir
  end

  def is_url?(string)
    URI.parse(string).scheme rescue nil
  end

  def read_anvil_metadata(root, name)
    return nil if is_url?(root)
    File.open(File.join(anvil_metadata_dir(root), name)).read.chomp rescue nil
  end

  def write_anvil_metadata(root, name, data)
    return if is_url?(root)
    File.open(File.join(anvil_metadata_dir(root), name), "w") do |file|
      file.puts data
    end
  end

end
