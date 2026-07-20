require "test_helper"

class Metadata::PageParserTest < ActiveSupport::TestCase
  setup do
    @page_url = URI.parse("https://example.com/product/1")
  end

  test "parses title, description, image and favicon from og tags" do
    html = <<~HTML
      <html><head>
        <title>Fallback Title</title>
        <meta property="og:title" content="OG Title">
        <meta property="og:description" content="OG Description">
        <meta property="og:image" content="/images/pic.jpg">
        <link rel="icon" href="/favicon-32.png">
      </head><body></body></html>
    HTML

    result = Metadata::PageParser.parse(html, @page_url)

    assert_equal "OG Title", result.title
    assert_equal "OG Description", result.description
    assert_equal "https://example.com/images/pic.jpg", result.image_url
    assert_equal "https://example.com/favicon-32.png", result.favicon_url
  end

  test "falls back to the title tag and meta description when og tags are absent" do
    html = <<~HTML
      <html><head>
        <title>Only Title</title>
        <meta name="description" content="Plain description">
      </head><body></body></html>
    HTML

    result = Metadata::PageParser.parse(html, @page_url)

    assert_equal "Only Title", result.title
    assert_equal "Plain description", result.description
  end

  test "falls back to /favicon.ico when no icon link is present" do
    html = "<html><head><title>No Icon</title></head><body></body></html>"

    result = Metadata::PageParser.parse(html, @page_url)

    assert_equal "https://example.com/favicon.ico", result.favicon_url
  end

  test "prefers a JSON-LD Product name over og:title" do
    html = <<~HTML
      <script type="application/ld+json">{"@type":"Product","name":"JSON Product Name"}</script>
      <meta property="og:title" content="OG Title">
    HTML

    result = Metadata::PageParser.parse(html, @page_url)

    assert_equal "JSON Product Name", result.title
  end

  test "parses a price amount into minor units using the currency factor" do
    html = <<~HTML
      <meta property="product:price:amount" content="129.90">
      <meta property="product:price:currency" content="BRL">
    HTML

    result = Metadata::PageParser.parse(html, @page_url)

    assert_equal 12990, result.default_expected_amount_minor
  end

  test "leaves the price nil when no price meta is present" do
    html = "<html><head><title>No Price</title></head></html>"

    result = Metadata::PageParser.parse(html, @page_url)

    assert_nil result.default_expected_amount_minor
  end
end
