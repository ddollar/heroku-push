class Heroku::Client

  # valid options:
  #
  # slug_url: url to a slug
  #
  def release(app_name, description, options={})
    release_options = { :description => description }.merge(options)
    json_decode(releases_api["/apps/#{app_name}/release"].post(release_options))
  end

private

  def releases_host
    ENV["RELEASES_HOST"] || "https://releases-production.herokuapp.com"
  end

  def releases_api
    RestClient::Resource.new(releases_host, Heroku::Auth.user, Heroku::Auth.password)
  end

end
