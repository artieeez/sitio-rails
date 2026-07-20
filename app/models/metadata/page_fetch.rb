class Metadata::PageFetch
  class Error < StandardError
    attr_reader :code

    def initialize(message, code:)
      super(message)
      @code = code
    end
  end

  class InvalidUrl < Error
    def initialize(message = "Invalid URL")
      super(message, code: "INVALID_URL")
    end
  end

  class SsrfBlocked < Error
    def initialize(message = "Host not allowed")
      super(message, code: "SSRF_BLOCKED")
    end
  end

  class UpstreamError < Error
    def initialize(message = "Upstream fetch failed")
      super(message, code: "UPSTREAM_ERROR")
    end
  end

  Result = Data.define(
    :title,
    :description,
    :image_url,
    :favicon_url,
    :default_expected_amount_minor
  )

  MAX_BODY_BYTES = 2 * 1024 * 1024
  FETCH_TIMEOUT_SECONDS = 10
  USER_AGENT = "SitioMetadataFetcher/1.0"

  def self.call(url_string, connection: nil)
    new(url_string, connection:).call
  end

  def initialize(url_string, connection: nil)
    @url_string = url_string
    @connection = connection
  end

  def call
    url = parse_url
    Metadata::SafeUrl.assert!(url)
    html = fetch_html(url)
    Metadata::PageParser.parse(html, url)
  end

  private
    def parse_url
      URI.parse(@url_string)
    rescue URI::InvalidURIError
      raise InvalidUrl
    end

    def fetch_html(url)
      response = http_connection.get(url.to_s) do |req|
        req.headers["Accept"] = "text/html,application/xhtml+xml;q=0.9,*/*;q=0.8"
        req.headers["User-Agent"] = USER_AGENT
        req.options.timeout = FETCH_TIMEOUT_SECONDS
        req.options.open_timeout = FETCH_TIMEOUT_SECONDS
      end

      raise UpstreamError unless response.success?

      content_type = response.headers["content-type"].to_s
      unless content_type.include?("text/html") || content_type.include?("application/xhtml")
        raise UpstreamError
      end

      body = response.body.to_s
      raise UpstreamError if body.bytesize > MAX_BODY_BYTES

      body
    rescue Faraday::Error
      raise UpstreamError
    end

    def http_connection
      @connection || begin
        require "faraday/follow_redirects"
        Faraday.new do |f|
          f.response :follow_redirects, limit: 5
          f.adapter Faraday.default_adapter
        end
      end
    end
end
