desc "Revendor"
task :revendor do
  FileUtils.rm_rf File.join(root, "vendor")

  vendor "anvil",       "https://github.com/ddollar/anvil-cli.git"
  vendor "progress",    "https://github.com/toy/progress.git"
end

def root
  File.dirname(__FILE__)
end

def vendor(name, git)
  system "git clone #{git} vendor/#{name}"
  Dir[File.join(root, "vendor", name, "**", ".git")].each do |dir|
    FileUtils.rm_rf dir
  end
end
