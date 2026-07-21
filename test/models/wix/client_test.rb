require "test_helper"
require "faraday/response/json"

class Wix::ClientTest < ActiveSupport::TestCase
  setup do
    @integration = WixIntegration.new(private_api_key: "test-key", site_id: "test-site")
  end

  test "get_product returns the product body" do
    client = build_client do |stubs|
      stubs.get("https://www.wixapis.com/stores-reader/v1/products/product-1") do
        [ 200, json_headers, { product: { id: "product-1", name: "Trip" } }.to_json ]
      end
    end

    product = client.get_product("product-1")

    assert_equal "product-1", product["id"]
    assert_equal "Trip", product["name"]
  end

  test "get_product raises NotFound on a 404" do
    client = build_client do |stubs|
      stubs.get("https://www.wixapis.com/stores-reader/v1/products/missing") { [ 404, json_headers, {}.to_json ] }
    end

    assert_raises(Wix::Client::NotFound) { client.get_product("missing") }
  end

  test "get_product raises UpstreamError on a 500" do
    client = build_client do |stubs|
      stubs.get("https://www.wixapis.com/stores-reader/v1/products/product-1") do
        [ 500, json_headers, { message: "boom" }.to_json ]
      end
    end

    error = assert_raises(Wix::Client::UpstreamError) { client.get_product("product-1") }
    assert_match "boom", error.message
  end

  test "raises ApiKeyMissing when no private API key is configured" do
    client = Wix::Client.new(integration: WixIntegration.new, connection: Faraday.new)

    assert_raises(Wix::Client::ApiKeyMissing) { client.get_product("product-1") }
  end

  test "sends the Authorization and wix-site-id headers" do
    seen_headers = nil
    client = build_client do |stubs|
      stubs.get("https://www.wixapis.com/stores-reader/v1/products/product-1") do |env|
        seen_headers = env.request_headers
        [ 200, json_headers, { product: { id: "product-1" } }.to_json ]
      end
    end

    client.get_product("product-1")

    assert_equal "test-key", seen_headers["Authorization"]
    assert_equal "test-site", seen_headers["wix-site-id"]
  end

  test "get_order returns the order body" do
    client = build_client do |stubs|
      stubs.get("https://www.wixapis.com/ecom/v1/orders/order-1") do
        [ 200, json_headers, { order: { id: "order-1", lineItems: [] } }.to_json ]
      end
    end

    order = client.get_order("order-1")

    assert_equal "order-1", order["id"]
  end

  test "get_order raises NotFound on a 404" do
    client = build_client do |stubs|
      stubs.get("https://www.wixapis.com/ecom/v1/orders/missing") { [ 404, json_headers, {}.to_json ] }
    end

    assert_raises(Wix::Client::NotFound) { client.get_order("missing") }
  end

  test "get_order raises UpstreamError on a 500" do
    client = build_client do |stubs|
      stubs.get("https://www.wixapis.com/ecom/v1/orders/order-1") do
        [ 500, json_headers, { message: "boom" }.to_json ]
      end
    end

    error = assert_raises(Wix::Client::UpstreamError) { client.get_order("order-1") }
    assert_match "boom", error.message
  end

  test "get_collection returns the first matching collection or nil" do
    client = build_client do |stubs|
      stubs.post("https://www.wixapis.com/stores-reader/v1/collections/query") do
        [ 200, json_headers, { collections: [ { id: "collection-1", name: "School" } ] }.to_json ]
      end
    end

    assert_equal "collection-1", client.get_collection("collection-1")["id"]
  end

  test "get_collection returns nil when Wix has no matching collection" do
    client = build_client do |stubs|
      stubs.post("https://www.wixapis.com/stores-reader/v1/collections/query") do
        [ 200, json_headers, { collections: [] }.to_json ]
      end
    end

    assert_nil client.get_collection("missing")
  end

  test "search_collections_by_prefix short-circuits on a blank prefix" do
    client = Wix::Client.new(integration: @integration, connection: Faraday.new { |f| f.adapter :test, Faraday::Adapter::Test::Stubs.new })

    assert_equal [], client.search_collections_by_prefix("  ")
  end

  test "search_products_in_collection_by_prefix filters client-side by name prefix" do
    client = build_client do |stubs|
      stubs.post("https://www.wixapis.com/stores-reader/v1/products/query") do
        [ 200, json_headers, { products: [ { name: "Passeio Sul" }, { name: "Excursão Norte" } ] }.to_json ]
      end
    end

    products = client.search_products_in_collection_by_prefix("collection-1", "Pass")

    assert_equal [ "Passeio Sul" ], products.map { |p| p["name"] }
  end

  test "update_collection returns the updated collection" do
    client = build_client do |stubs|
      stubs.patch("https://www.wixapis.com/stores/v1/collections/collection-1") do
        [ 200, json_headers, { collection: { id: "collection-1", visible: false } }.to_json ]
      end
    end

    assert_equal false, client.update_collection("collection-1", visible: false)["visible"]
  end

  test "update_product returns the updated product" do
    client = build_client do |stubs|
      stubs.patch("https://www.wixapis.com/stores/v1/products/product-1") do
        [ 200, json_headers, { product: { id: "product-1", visible: false } }.to_json ]
      end
    end

    assert_equal false, client.update_product("product-1", visible: false)["visible"]
  end

  test "delete_product raises NotFound on a 404" do
    client = build_client do |stubs|
      stubs.delete("https://www.wixapis.com/stores/v1/products/missing") { [ 404, json_headers, {}.to_json ] }
    end

    assert_raises(Wix::Client::NotFound) { client.delete_product("missing") }
  end

  test "list_sites does not send a wix-site-id header" do
    seen_headers = nil
    client = build_client do |stubs|
      stubs.post("https://www.wixapis.com/site-list/v2/sites/query") do |env|
        seen_headers = env.request_headers
        [ 200, json_headers, { sites: [] }.to_json ]
      end
    end

    client.list_sites

    assert_not seen_headers.key?("wix-site-id")
  end

  private
    def build_client
      stubs = Faraday::Adapter::Test::Stubs.new
      yield stubs
      connection = Faraday.new { |f| f.response :json, content_type: /\bjson$/; f.adapter :test, stubs }
      Wix::Client.new(integration: @integration, connection:)
    end

    def json_headers = { "Content-Type" => "application/json" }
end
