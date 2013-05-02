require "anvil"
require "anvil/helpers"
require "net/http"
require "net/https"
require "rest_client"

class Anvil::Builder

  include Anvil::Helpers

  class BuildError < StandardError; end

  attr_reader :source

  def initialize(source)
    @source = source
  end

  def build(options={})
    uri  = URI.parse("#{anvil_host}/build")

    if uri.scheme == "https"
      proxy = https_proxy
    else
      proxy = http_proxy
    end

    if proxy
      proxy_uri = URI.parse(proxy)
      http = Net::HTTP.new(uri.host, uri.port, proxy_uri.host, proxy_uri.port, proxy_uri.user, proxy_uri.password)
    else
      http = Net::HTTP.new(uri.host, uri.port)
    end

    if uri.scheme == "https"
      http.use_ssl = true
      http.verify_mode = OpenSSL::SSL::VERIFY_NONE
    end

    req = Net::HTTP::Post.new uri.request_uri

    req.initialize_http_header "User-Agent" => Anvil.agent

    Anvil.headers.each do |name, val|
      next if name.to_s.strip == ""
      req.initialize_http_header name => val.to_s
    end

    req.set_form_data({
      "buildpack" => options[:buildpack],
      "cache"     => options[:cache],
      "env"       => json_encode(options[:env] || {}),
      "source"    => source,
      "type"      => options[:type]
    })

    slug_url = nil

    http.request(req) do |res|
      slug_url = res["x-slug-url"]

      begin
        res.read_body do |chunk|
          yield chunk
        end
      rescue EOFError
        puts
        raise BuildError, "terminated unexpectedly"
      end

      manifest_id = [res["x-manifest-id"]].flatten.first
      code = Integer(String.new(anvil["/exit/#{manifest_id}"].get.to_s))
      raise BuildError, "exited #{code}" unless code.zero?
    end

    slug_url
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

  def http_proxy
    proxy = ENV['HTTP_PROXY'] || ENV['http_proxy']
    if proxy && !proxy.empty?
      unless /^[^:]+:\/\// =~ proxy
        proxy = "http://" + proxy
      end
      proxy
    else
      nil
    end
  end

  def https_proxy
    proxy = ENV['HTTPS_PROXY'] || ENV['https_proxy'] || ENV["HTTP_PROXY"] || ENV["http_proxy"]
    if proxy && !proxy.empty?
      unless /^[^:]+:\/\// =~ proxy
        proxy = "https://" + proxy
      end
      proxy
    else
      nil
    end
  end

end
