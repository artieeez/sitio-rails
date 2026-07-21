require "test_helper"

class Wix::CollectionsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
  end

  test "requires authentication" do
    sign_out
    get autocomplete_wix_collections_path, params: { prefix: "Esc" }, as: :json

    assert_redirected_to new_session_path
  end

  test "autocomplete returns matching collections" do
    collections = [ { "id" => "collection-1", "name" => "Escola Feliz", "visible" => true } ]

    with_wix_client(FakeClient.new(collections_by_prefix: collections)) do
      get autocomplete_wix_collections_path, params: { prefix: "Esc" }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.size
    assert_equal "collection-1", body.first["id"]
    assert_equal "Escola Feliz", body.first["name"]
  end

  test "show returns the collection" do
    collection = { "id" => "collection-1", "name" => "Escola Feliz", "numberOfProducts" => 3 }

    with_wix_client(FakeClient.new(collection:)) do
      get wix_collection_path("collection-1"), as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "collection-1", body["id"]
    assert_equal 3, body["number_of_products"]
  end

  test "show returns not_found when the collection does not exist" do
    with_wix_client(FakeClient.new(collection: nil)) do
      get wix_collection_path("collection-missing"), as: :json
    end

    assert_response :not_found
  end

  test "returns service_unavailable when the Wix API key is not configured" do
    with_wix_client(FakeClient.new(error: Wix::Client::ApiKeyMissing.new)) do
      get autocomplete_wix_collections_path, params: { prefix: "Esc" }, as: :json
    end

    assert_response :service_unavailable
    assert_equal "wix_not_configured", JSON.parse(response.body)["code"]
  end

  test "returns bad_gateway when the Wix API fails upstream" do
    with_wix_client(FakeClient.new(error: Wix::Client::UpstreamError.new("boom", status: 500))) do
      get autocomplete_wix_collections_path, params: { prefix: "Esc" }, as: :json
    end

    assert_response :bad_gateway
  end

  class FakeClient
    def initialize(collections_by_prefix: [], collection: nil, error: nil)
      @collections_by_prefix = collections_by_prefix
      @collection = collection
      @error = error
    end

    def search_collections_by_prefix(_prefix)
      raise @error if @error

      @collections_by_prefix
    end

    def get_collection(_id)
      raise @error if @error

      @collection
    end
  end

  private
    def with_wix_client(fake_client)
      original_new = Wix::Client.method(:new)
      Wix::Client.define_singleton_method(:new) { |*, **| fake_client }
      yield
    ensure
      Wix::Client.define_singleton_method(:new, original_new)
    end
end
