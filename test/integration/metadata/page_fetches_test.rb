require "test_helper"

class Metadata::PageFetchesTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
  end

  test "requires authentication" do
    sign_out
    post metadata_page_fetch_path, params: { url: "https://example.com/" }, as: :json

    assert_redirected_to new_session_path
  end

  test "creates metadata for a valid url" do
    result = Metadata::PageFetch::Result.new(
      title: "Example title",
      description: "Example description",
      image_url: "https://example.com/pic.jpg",
      favicon_url: "https://example.com/favicon.ico",
      default_expected_amount_minor: 1990
    )

    stub_page_fetch(result) do
      post metadata_page_fetch_path, params: { url: "https://example.com/" }, as: :json
    end

    assert_response :created
    body = JSON.parse(response.body)
    assert_equal "Example title", body["title"]
    assert_equal "https://example.com/favicon.ico", body["favicon_url"]
    assert_equal 1990, body["default_expected_amount_minor"]
  end

  test "returns 400 for an SSRF-blocked url" do
    post metadata_page_fetch_path, params: { url: "http://localhost/" }, as: :json

    assert_response :bad_request
    assert_equal "SSRF_BLOCKED", JSON.parse(response.body)["code"]
  end

  test "returns 400 for an invalid url" do
    post metadata_page_fetch_path, params: { url: "file:///etc/passwd" }, as: :json

    assert_response :bad_request
    assert_equal "INVALID_URL", JSON.parse(response.body)["code"]
  end

  private
    def stub_page_fetch(result)
      original = Metadata::PageFetch.method(:call)
      Metadata::PageFetch.define_singleton_method(:call) { |*, **| result }
      yield
    ensure
      Metadata::PageFetch.define_singleton_method(:call, original)
    end
end
