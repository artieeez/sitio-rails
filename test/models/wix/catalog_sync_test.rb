require "test_helper"

class Wix::CatalogSyncTest < ActiveSupport::TestCase
  class FakeClient
    attr_reader :update_collection_calls, :update_product_calls

    def initialize(collections: {}, products: {})
      @collections = collections
      @products = products
      @update_collection_calls = []
      @update_product_calls = []
    end

    def get_collection(id) = @collections[id]
    def get_product(id) = @products[id]

    def update_collection(id, attrs)
      @update_collection_calls << [ id, attrs ]
      @collections[id]
    end

    def update_product(id, attrs)
      @update_product_calls << [ id, attrs ]
      @products[id]
    end
  end

  def sync_for(event_type, payload, client: FakeClient.new)
    event = Wix::Event.new(event_type: event_type, wix_entity_id: "", payload: payload)
    Wix::CatalogSync.new(event, client: client)
  end

  test "collection_created creates a school and applies visibility" do
    sync = sync_for(Wix::Event::COLLECTION_CREATED, {
      "collectionId" => "collection-new",
      "name" => "Escola Nova",
      "visible" => true,
      "media" => { "mainMedia" => { "image" => { "url" => "https://img.example.com/1.jpg" } } }
    })

    assert_difference "School.count", 1 do
      sync.collection_created
    end

    school = School.find_by!(wix_collection_id: "collection-new")
    assert_equal "Escola Nova", school.title
    assert_equal "https://img.example.com/1.jpg", school.image_url
    assert school.active?
    assert school.store_visible?
  end

  test "collection_created conceals in store when visible is false" do
    sync = sync_for(Wix::Event::COLLECTION_CREATED, { "collectionId" => "collection-hidden", "name" => "Escola Oculta", "visible" => false })

    sync.collection_created

    school = School.find_by!(wix_collection_id: "collection-hidden")
    assert school.store_concealed?
    assert school.active?
  end

  test "collection_created is a no-op when a school already exists for that collection" do
    sync = sync_for(Wix::Event::COLLECTION_CREATED, { "collectionId" => schools(:active).wix_collection_id, "name" => "Duplicada" })

    assert_no_difference "School.count" do
      sync.collection_created
    end
  end

  test "collection_changed updates the matching school from the fetched collection" do
    school = schools(:active)
    client = FakeClient.new(collections: {
      school.wix_collection_id => { "name" => "Nome Atualizado", "description" => "Nova descrição", "visible" => false, "media" => {} }
    })
    sync = sync_for(Wix::Event::COLLECTION_CHANGED, { "collectionId" => school.wix_collection_id }, client: client)

    sync.collection_changed
    school.reload

    assert_equal "Nome Atualizado", school.title
    assert_equal "Nova descrição", school.description
    assert school.store_concealed?
  end

  test "collection_changed drift-heals a missing school from the fetched collection" do
    client = FakeClient.new(collections: { "collection-drift" => { "name" => "Escola Drift", "visible" => true } })
    sync = sync_for(Wix::Event::COLLECTION_CHANGED, { "collectionId" => "collection-drift" }, client: client)

    assert_difference "School.count", 1 do
      sync.collection_changed
    end

    assert School.exists?(wix_collection_id: "collection-drift", title: "Escola Drift")
  end

  test "collection_changed is a no-op when the collection no longer exists upstream" do
    client = FakeClient.new(collections: {})
    sync = sync_for(Wix::Event::COLLECTION_CHANGED, { "collectionId" => "collection-gone" }, client: client)

    assert_no_difference "School.count" do
      sync.collection_changed
    end
  end

  test "collection_deleted deactivates a school with passengers and pushes visible false upstream" do
    school = schools(:active)
    client = FakeClient.new
    sync = sync_for(Wix::Event::COLLECTION_DELETED, { "collectionId" => school.wix_collection_id }, client: client)

    sync.collection_deleted

    assert school.reload.deactivated?
    assert_equal 1, client.update_collection_calls.size
    assert_equal false, client.update_collection_calls.first[1][:visible]
  end

  test "collection_deleted hard-destroys a school with no passengers" do
    school = School.create!(title: "Sem Alunos", wix_collection_id: "collection-empty")
    sync = sync_for(Wix::Event::COLLECTION_DELETED, { "collectionId" => "collection-empty" })

    sync.collection_deleted

    assert_not School.exists?(school.id)
  end

  test "product_created creates a trip under the matching school" do
    school = schools(:concealed)
    school.update!(wix_collection_id: "collection-for-product")
    client = FakeClient.new(products: {
      "product-new" => {
        "name" => "Passeio Novo",
        "visible" => true,
        "collectionIds" => [ "collection-for-product" ],
        "priceData" => { "price" => "150.5" },
        "slug" => "passeio-novo"
      }
    })
    sync = sync_for(Wix::Event::PRODUCT_CREATED, { "productId" => "product-new" }, client: client)

    assert_difference "Trip.count", 1 do
      sync.product_created
    end

    trip = Trip.find_by!(wix_product_id: "product-new")
    assert_equal school, trip.school
    assert_equal "Passeio Novo", trip.title
    assert_equal 15050, trip.default_expected_amount_minor
  end

  test "product_created is a no-op when the trip already exists (echo guard)" do
    sync = sync_for(Wix::Event::PRODUCT_CREATED, { "productId" => trips(:active).wix_product_id })

    assert_no_difference "Trip.count" do
      sync.product_created
    end
  end

  test "product_created is a no-op when zero schools match the product collections" do
    client = FakeClient.new(products: { "product-orphan" => { "name" => "Sem Escola", "collectionIds" => [] } })
    sync = sync_for(Wix::Event::PRODUCT_CREATED, { "productId" => "product-orphan" }, client: client)

    assert_no_difference "Trip.count" do
      sync.product_created
    end
  end

  test "product_changed updates the matching trip snapshot and visibility" do
    trip = trips(:active)
    client = FakeClient.new(products: {
      trip.wix_product_id => { "name" => "Atualizado", "visible" => false, "priceData" => { "price" => "10" } }
    })
    sync = sync_for(Wix::Event::PRODUCT_CHANGED, { "productId" => trip.wix_product_id }, client: client)

    sync.product_changed
    trip.reload

    assert_equal "Atualizado", trip.title
    assert trip.store_concealed?
  end

  test "product_changed drift-heals a trip when no local trip is linked yet" do
    school = schools(:active)
    client = FakeClient.new(products: {
      "product-drift" => { "name" => "Drift Trip", "visible" => true, "collectionIds" => [ school.wix_collection_id ] }
    })
    sync = sync_for(Wix::Event::PRODUCT_CHANGED, { "productId" => "product-drift" }, client: client)

    assert_difference "Trip.count", 1 do
      sync.product_changed
    end

    assert Trip.exists?(wix_product_id: "product-drift", school_id: school.id)
  end

  test "product_deleted deactivates a trip with passengers and pushes visible false upstream" do
    trip = trips(:active)
    client = FakeClient.new
    sync = sync_for(Wix::Event::PRODUCT_DELETED, { "productId" => trip.wix_product_id }, client: client)

    sync.product_deleted

    assert trip.reload.deactivated?
    assert_equal 1, client.update_product_calls.size
    assert_equal false, client.update_product_calls.first[1][:visible]
  end

  test "product_deleted hard-destroys a trip with no passengers" do
    trip = trips(:inactive)
    trip.update!(wix_product_id: "product-empty")
    sync = sync_for(Wix::Event::PRODUCT_DELETED, { "productId" => "product-empty" })

    sync.product_deleted

    assert_not Trip.exists?(trip.id)
  end
end
