require "anvil/builder"
require "anvil/helpers"
require "net/http"
require "net/https"
require "pathname"
require "rest_client"

class Anvil::Manifest

  include Anvil::Helpers

  PUSH_THREAD_COUNT = 40

  attr_reader :cache_url
  attr_reader :dir
  attr_reader :manifest

  def initialize(dir=nil, options={})
    @dir = dir
    @ignore = options[:ignore] || []
    @manifest = @dir ? directory_manifest(@dir, :ignore => @ignore) : {}
    @cache_url = options[:cache]
  end

  def build(options={})
    uri  = URI.parse("#{anvil_host}/manifest/build")
    http = Net::HTTP.new(uri.host, uri.port)

    if uri.scheme == "https"
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    req = Net::HTTP::Post.new uri.request_uri

    env = options[:env] || {}

    req.initialize_http_header "User-Agent" => Anvil.agent
    req["User-Agent"] = Anvil.agent

    Anvil.headers.each do |name, val|
      next if name.to_s.strip == ""
      req[name] = val.to_s
    end

    req.set_form_data({
      "buildpack" => options[:buildpack],
      "cache"     => @cache_url,
      "env"       => json_encode(options[:env] || {}),
      "keepalive" => "1",
      "manifest"  => self.to_json
    })

    slug_url = nil

    http.request(req) do |res|
      slug_url = res["x-slug-url"]
      @cache_url = res["x-cache-url"]

      begin
        res.read_body do |chunk|
          yield chunk.gsub("\000\000\000", "")
        end
      rescue EOFError
        puts
        raise Anvil::Builder::BuildError, "terminated unexpectedly"
      end

      code = if res["x-exit-code"].nil?
        manifest_id = Array(res["x-manifest-id"]).first
        Integer(String.new(anvil["/exit/#{manifest_id}"].get.to_s))
      else
        res["x-exit-code"].first.to_i
      end

      raise Anvil::Builder::BuildError, "exited #{code}" unless code.zero?
    end

    slug_url
  end

  def save
    res = anvil["/manifest"].post(:manifest => self.to_json)
    res.headers[:location]
  end

  def manifest_by_hash(manifest)
    manifest.inject({}) do |ax, (name, file)|
      ax.update file["hash"] => file.merge("name" => name)
    end
  end

  def missing
    mbh = manifest_by_hash(@manifest)
    json_decode(anvil["/manifest/diff"].post(:manifest => self.to_json).to_s).inject({}) do |ax, hash|
      ax.update hash => mbh[hash]
    end
  end

  def upload(missing, &blk)
    upload_hashes missing, &blk
    missing.length
  end

  def to_json
    json_encode(@manifest)
  end

  def add(filename)
    @manifest[filename] = file_manifest(filename)
  end

private

  def anvil
    @anvil ||= RestClient::Resource.new(anvil_host, :headers => anvil_headers)
  end

  def anvil_headers
    { "User-Agent" => Anvil.agent }
  end

  def anvil_host
    ENV["ANVIL_HOST"] || "https://api.anvilworks.org"
  end

  def directory_manifest(dir, options={})
    root = Pathname.new(dir)
    ignore = options[:ignore] || []

    if File.exists?("#{dir}/.slugignore")
      ignore += File.read("#{dir}/.slugignore").split("\n")
    end

    Dir.glob(File.join(dir, "**", "*"), File::FNM_DOTMATCH).inject({}) do |hash, file|
      relative = Pathname.new(file).relative_path_from(root).to_s
      next(hash) if ignore.include?(relative)
      next(hash) if %w( . .. ).include?(File.basename(file))
      next(hash) if File.directory?(file)
      next(hash) if File.pipe?(file)
      next(hash) if file =~ /\.anvil/
      next(hash) if file =~ /\.git/
      next(hash) if file =~ /\.swp$/
      next(hash) unless file =~ /^[A-Za-z0-9\-\_\.\/]*$/
      hash[relative] = file_manifest(file)
      hash
    end
  end

  def file_manifest(file)
    stat = File.stat(file)
    manifest = {
      "mtime" => stat.mtime.to_i,
      "mode"  => "%o" % stat.mode,
      "size"  => stat.size.to_s
    }
    if File.symlink?(file)
      manifest["link"] = File.readlink(file)
    else
      manifest["hash"] = calculate_hash(file)
    end
    manifest
  end

  def calculate_hash(filename)
    Digest::SHA2.hexdigest(File.open(filename, "rb").read)
  end

  def upload_file(filename, hash=nil)
    hash ||= calculate_hash(filename)
    anvil["/file/#{hash}"].post :data => File.new(filename, "rb")
    hash
  rescue RestClient::Forbidden => ex
    error "error uploading #{filename}: #{ex.http_body}"
  end

  def upload_hashes(hashes, &blk)
    mbh = manifest_by_hash(@manifest)
    filenames_by_hash = @manifest.inject({}) do |ax, (name, file_manifest)|
      ax.update file_manifest["hash"] => File.join(@dir.to_s, name)
    end
    bucket_hashes = hashes.inject({}) do |ax, hash|
      index = hash.hash % PUSH_THREAD_COUNT
      ax[index] ||= []
      ax[index]  << hash
      ax
    end
    threads = bucket_hashes.values.map do |hashes|
      Thread.new do
        hashes.each do |hash|
          upload_file filenames_by_hash[hash], hash
          blk.call mbh[hash]
        end
      end
    end
    threads.each(&:join)
  end

end
