require "test_helper"

class Metadata::PageFetchTest < ActiveSupport::TestCase
  test "fetches and parses metadata from an HTML page" do
    html = <<~HTML
      <html><head>
        <title>Store Title</title>
        <meta property="og:title" content="OG Title">
        <link rel="icon" href="/favicon.png">
      </head></html>
    HTML

    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://example.com/") { [ 200, { "Content-Type" => "text/html" }, html ] }
    conn = Faraday.new { |f| f.adapter :test, stubs }

    result = with_safe_url_bypassed do
      Metadata::PageFetch.call("https://example.com/", connection: conn)
    end

    assert_equal "OG Title", result.title
    assert_equal "https://example.com/favicon.png", result.favicon_url
  end

  test "raises UpstreamError when the response is not html" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://example.com/") { [ 200, { "Content-Type" => "application/json" }, "{}" ] }
    conn = Faraday.new { |f| f.adapter :test, stubs }

    assert_raises Metadata::PageFetch::UpstreamError do
      with_safe_url_bypassed do
        Metadata::PageFetch.call("https://example.com/", connection: conn)
      end
    end
  end

  test "raises UpstreamError when the upstream responds with an error status" do
    stubs = Faraday::Adapter::Test::Stubs.new
    stubs.get("https://example.com/") { [ 500, {}, "boom" ] }
    conn = Faraday.new { |f| f.adapter :test, stubs }

    assert_raises Metadata::PageFetch::UpstreamError do
      with_safe_url_bypassed do
        Metadata::PageFetch.call("https://example.com/", connection: conn)
      end
    end
  end

  test "raises InvalidUrl for an unparsable url" do
    assert_raises Metadata::PageFetch::InvalidUrl do
      Metadata::PageFetch.call("http://[invalid")
    end
  end

  private
    def with_safe_url_bypassed
      original = Metadata::SafeUrl.method(:assert!)
      Metadata::SafeUrl.define_singleton_method(:assert!) { |*| true }
      yield
    ensure
      Metadata::SafeUrl.define_singleton_method(:assert!, original)
    end
end
