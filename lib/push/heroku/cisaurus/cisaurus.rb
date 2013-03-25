require "json"

class Cisaurus

  CISAURUS_CLIENT_VERSION = "0.7-ALPHA"
  CISAURUS_HOST = ENV['CISAURUS_HOST'] || "cisaurus.heroku.com"

  def initialize(api_key, host = CISAURUS_HOST, api_version = "v1")
    protocol  = (host.start_with? "localhost") ? "http" : "https"

    RestClient.proxy = case protocol
    when "http"
      http_proxy
    when "https"
      https_proxy
    end

    @base_url = "#{protocol}://:#{api_key}@#{host}"
    @ver_url  = "#{@base_url}/#{api_version}"
  end

  def downstreams(app, depth=nil)
    JSON.parse RestClient.get pipeline_resource(app, "downstreams"), options(params :depth => depth)
  end

  def addDownstream(app, ds)
    RestClient.post pipeline_resource(app, "downstreams", ds), "", options
  end

  def removeDownstream(app, ds)
    RestClient.delete pipeline_resource(app, "downstreams", ds), options
  end

  def diff(app)
    JSON.parse RestClient.get pipeline_resource(app, "diff"), options
  end

  def promote(app, interval = 2)
    response = RestClient.post pipeline_resource(app, "promote"), "", options
    while response.code == 202
      response = RestClient.get @base_url + response.headers[:location], options
      sleep(interval)
      yield
    end
    JSON.parse response
  end

  def release(app, description, slug_url, interval = 2)
    payload = {:description => description, :slug_url => slug_url}
    extras = {:content_type => :json, :accept => :json}
    response = RestClient.post app_resource(app, "release"), JSON.generate(payload), options(extras)
    while response.code == 202
      response = RestClient.get @base_url + response.headers[:location], options(extras)
      sleep(interval)
      yield
    end
    JSON.parse response
  end

  private

  def app_resource(app, *extras)
    "#{@ver_url}/" + extras.unshift("apps/#{app}").join("/")
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
    proxy = ENV['HTTPS_PROXY'] || ENV['https_proxy']
    if proxy && !proxy.empty?
      unless /^[^:]+:\/\// =~ proxy
        proxy = "https://" + proxy
      end
      proxy
    else
      nil
    end
  end

  def pipeline_resource(app, *extras)
    app_resource(app, extras.unshift("pipeline").join("/"))
  end

  def params(tuples = {})
    { :params => tuples.reject { |k,v| k.nil? || v.nil? } }
  end

  def options(extras = {})
    {
        'User-Agent'       => "heroku-push-cli/#{CISAURUS_CLIENT_VERSION}",
        'X-Ruby-Version'   => RUBY_VERSION,
        'X-Ruby-Platform'  => RUBY_PLATFORM
    }.merge(extras)
  end
end
