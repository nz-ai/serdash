# frozen_string_literal: true

Rails.application.config.middleware.use OmniAuth::Builder do
  provider :google_oauth2, ENV["GOOGLE_CLIENT_ID"], ENV["GOOGLE_CLIENT_SECRET"], {
    scope: "email,profile"
  } if ENV["GOOGLE_CLIENT_ID"].present?
  provider :github, ENV["GITHUB_CLIENT_ID"], ENV["GITHUB_CLIENT_SECRET"], {
    scope: "user:email"
  } if ENV["GITHUB_CLIENT_ID"].present?
end

OmniAuth.config.allowed_request_methods = [:get, :post]
OmniAuth.config.silence_get_warning = true
