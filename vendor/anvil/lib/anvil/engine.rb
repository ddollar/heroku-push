require "anvil"
require "anvil/builder"
require "anvil/helpers"
require "anvil/manifest"
require "anvil/version"
require "progress"
require "thread"
require "uri"

class Anvil::Engine

  extend Anvil::Helpers

  def self.build(source, options={})
    if options[:pipeline]
      old_stdout = $stdout.dup
      $stdout = $stderr
    end

    source ||= "."

    buildpack = options[:buildpack] || read_anvil_metadata(source, "buildpack")

    build_options = {
      :buildpack => prepare_buildpack(buildpack),
      :type      => options[:type] || "tgz"
    }

    builder = if is_url?(source)
      Anvil::Builder.new(source)
    else
      manifest = Anvil::Manifest.new(File.expand_path(source),
        :cache  => read_anvil_metadata(source, "cache"),
        :ignore => options[:ignore])
      upload_missing manifest

      manifest
    end

    slug_url = builder.build(build_options) do |chunk|
      print chunk
    end

    unless is_url?(source)
      write_anvil_metadata source, "buildpack", buildpack
      write_anvil_metadata source, "cache",     manifest.cache_url
    end

    old_stdout.puts slug_url if options[:pipeline]

    slug_url
  end

  def self.version
    puts Anvil::VERSION
  end

  def self.prepare_buildpack(buildpack)
    buildpack = buildpack.to_s
    if buildpack == ""
      buildpack
    elsif is_url?(buildpack)
      buildpack
    elsif buildpack =~ /\A\w+\/\w+\Z/
      "http://codon-buildpacks.s3.amazonaws.com/buildpacks/#{buildpack}.tgz"
    elsif File.exists?(buildpack) && File.directory?(buildpack)
      manifest = Anvil::Manifest.new(buildpack)
      upload_missing manifest, "buildpack"
      manifest.save
    else
      raise Anvil::Builder::BuildError.new("unrecognized buildpack specification: #{buildpack}")
    end
  end

  def self.upload_missing(manifest, title="app")
    print "Checking for #{title} files to sync... "
    missing = manifest.missing
    puts "done, #{missing.length} files needed"

    return if missing.length.zero?

    queue = Queue.new
    total_size = missing.map { |hash, file| file["size"].to_i }.inject(&:+)

    display = Thread.new do
      Progress.start "Uploading", total_size
      while (msg = queue.pop).first != :done
        case msg.first
          when :step then Progress.step msg.last.to_i
        end
      end
      Progress.stop
    end

    if missing.length > 0
      manifest.upload(missing.keys) do |file|
        queue << [:step, file["size"].to_i]
      end
      queue << [:done, nil]
    end

    display.join
  end

end
