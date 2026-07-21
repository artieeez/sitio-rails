require "test_helper"

class Wix::ProductsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
  end

  test "requires authentication" do
    sign_out
    get autocomplete_wix_products_path, params: { school_id: schools(:active).id, prefix: "Pas" }, as: :json

    assert_redirected_to new_session_path
  end

  test "autocomplete returns matching products for the school's collection" do
    products = [ { "id" => "product-1", "name" => "Passeio Legal", "visible" => true } ]

    with_wix_client(FakeClient.new(products_in_collection: products)) do
      get autocomplete_wix_products_path, params: { school_id: schools(:active).id, prefix: "Pas" }, as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal 1, body.size
    assert_equal "product-1", body.first["id"]
  end

  test "autocomplete returns an empty array when the school has no Wix collection" do
    with_wix_client(FakeClient.new) do
      get autocomplete_wix_products_path, params: { school_id: schools(:inactive).id, prefix: "Pas" }, as: :json
    end

    assert_response :success
    assert_equal [], JSON.parse(response.body)
  end

  test "show returns the product with form-fill fields" do
    product = {
      "id" => "product-1",
      "name" => "Passeio Legal",
      "slug" => "passeio-legal",
      "description" => "<p>Desc</p>",
      "media" => { "mainMedia" => { "image" => { "id" => "media-1", "url" => "https://cdn.example/img.jpg" } } },
      "productPageUrl" => { "base" => "https://shop.example.com", "path" => "/product/passeio-legal" },
      "priceData" => { "price" => 150.5, "currency" => "BRL" }
    }

    with_wix_client(FakeClient.new(product:)) do
      get wix_product_path("product-1"), as: :json
    end

    assert_response :success
    body = JSON.parse(response.body)
    assert_equal "product-1", body["id"]
    assert_equal "Passeio Legal", body["name"]
    assert_equal 15050, body["default_expected_amount_minor"]
    assert_equal "https://shop.example.com/product/passeio-legal", body["product_page_url"]
    assert_equal "media-1", body["wix_media_file_id"]
  end

  test "returns not_found when the product does not exist upstream" do
    with_wix_client(FakeClient.new(error: Wix::Client::NotFound.new("missing", status: 404))) do
      get wix_product_path("product-missing"), as: :json
    end

    assert_response :not_found
  end

  class FakeClient
    def initialize(products_in_collection: [], product: nil, error: nil)
      @products_in_collection = products_in_collection
      @product = product
      @error = error
    end

    def search_products_in_collection_by_prefix(_collection_id, _prefix)
      raise @error if @error

      @products_in_collection
    end

    def get_product(_id)
      raise @error if @error

      @product
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
