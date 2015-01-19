require "anvil"
require "anvil/engine"
require "cgi"
require "digest/sha2"
require "heroku/command/base"
require "net/https"
require "pathname"
require "progress"
require "tmpdir"
require "uri"

# deploy code
#
class Heroku::Command::Push < Heroku::Command::Base

  # push [SOURCE]
  #
  # deploy code to heroku
  #
  # if SOURCE is a local directory, the contents of the directory will be built
  # if SOURCE is a git URL, the contents of the repo will be built
  # if SOURCE is a tarball URL, the contents of the tarball will be built
  #
  # SOURCE will default to "."
  #
  # -b, --buildpack URL  # use a custom buildpack
  #
  def index
    source = shift_argument || "."
    validate_arguments!
    release_to = app # validate that we have an app

    user = api.post_login("", Heroku::Auth.password).body["email"]

    Anvil.append_agent "(heroku-push)"
    Anvil.headers["X-Heroku-User"] = user
    Anvil.headers["X-Heroku-App"]  = release_to

    slug_url = Anvil::Engine.build source,
      :buildpack => options[:buildpack],
      :ignore    => process_gitignore(source)

    action("Releasing to #{app}") do
      cisaurus = Cisaurus.new(Heroku::Auth.password)
      release = cisaurus.release(app, ENV["HEROKU_RELEASE_DESC"] || "Pushed by #{user}", slug_url) {
        print "."
        $stdout.flush
      }
      status release["release"]
    end
  rescue Anvil::Builder::BuildError => ex
    puts "ERROR: Build failed, #{ex.message}"
    exit 1
  end

private

  def is_url?(string)
    URI.parse(string).scheme rescue nil
  end

  def prepare_buildpack(buildpack)
    if buildpack == ""
      buildpack
    elsif is_url?(buildpack)
      buildpack
    elsif buildpack =~ /\A\w+\/\w+\Z/
      "http://buildkits-dev.s3.amazonaws.com/buildpacks/#{buildpack}.tgz"
    elsif File.exists?(buildpack) && File.directory?(buildpack)
      print "Uploading buildpack... "
      manifest = Anvil::Manifest.new(buildpack)
      manifest.upload
      manifest.save
      puts "done"
    else
      error "unrecognized buildpack specification: #{buildpack}"
    end
  end

  def process_gitignore(source)
    return [] if is_url?(source)
    return [] unless File.exists?("#{source}/.git")
    Dir.chdir(source) do
      %x{ git ls-files --others -i --exclude-standard }.split("\n")
    end
  end

end
