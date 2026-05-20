require "net/http"
require "json"
require "uri"

class AssetTrackerController < ApplicationController
  allow_unauthenticated_access
  layout false
  skip_before_action :verify_authenticity_token

  YAHOO_QUERY1 = "https://query1.finance.yahoo.com".freeze
  YAHOO_QUERY2 = "https://query2.finance.yahoo.com".freeze

  def index
  end

  def chart
    symbol = sanitize_symbol(params[:symbol])
    range = params[:range].presence || "1y"
    interval = params[:interval].presence || "1d"

    return render(json: { error: "invalid symbol" }, status: :bad_request) if symbol.blank?

    url = "#{YAHOO_QUERY1}/v8/finance/chart/#{URI.encode_www_form_component(symbol)}" \
          "?range=#{URI.encode_www_form_component(range)}&interval=#{URI.encode_www_form_component(interval)}&includePrePost=false"
    render json: proxy_json(url)
  end

  def news
    symbol = sanitize_symbol(params[:symbol])
    return render(json: { error: "invalid symbol" }, status: :bad_request) if symbol.blank?

    url = "#{YAHOO_QUERY2}/v1/finance/search?q=#{URI.encode_www_form_component(symbol)}" \
          "&quotesCount=1&newsCount=10&enableFuzzyQuery=false"
    render json: proxy_json(url)
  end

  def search
    q = params[:q].to_s.strip
    return render(json: { quotes: [] }) if q.blank?

    url = "#{YAHOO_QUERY2}/v1/finance/search?q=#{URI.encode_www_form_component(q)}" \
          "&quotesCount=10&newsCount=0&enableFuzzyQuery=false"
    render json: proxy_json(url)
  end

  private

  def sanitize_symbol(raw)
    raw.to_s.strip.upcase.gsub(/[^A-Z0-9.\-=^]/, "")
  end

  def proxy_json(url)
    uri = URI.parse(url)
    req = Net::HTTP::Get.new(uri)
    req["User-Agent"] = "Mozilla/5.0 (compatible; AssetTracker/1.0)"
    req["Accept"] = "application/json"

    http = Net::HTTP.new(uri.host, uri.port)
    http.use_ssl = (uri.scheme == "https")
    http.open_timeout = 5
    http.read_timeout = 10
    res = http.request(req)

    JSON.parse(res.body)
  rescue => e
    { "error" => e.message }
  end
end
