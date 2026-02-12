# frozen_string_literal: true

require "net/http"

class DiscoveryController < ApplicationController
  before_action :require_login

  def index
    @subnet = params[:subnet] || ENV["DISCOVERY_SUBNET"] || "192.168.1.0/24"
    return unless params[:subnet].present?

    uri = URI("#{ENV["COLLECTOR_URL"] || "http://collector:3001"}/v1/discover?subnet=#{CGI.escape(params[:subnet])}")
    http = Net::HTTP.new(uri.host, uri.port)
    http.read_timeout = 130
    resp = http.get(uri.request_uri)
    @result = resp.is_a?(Net::HTTPSuccess) ? JSON.parse(resp.body) : { "error" => resp.message }
  rescue StandardError => e
    @result = { "error" => e.message }
  end
end
