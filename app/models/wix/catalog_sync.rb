# Dispatches a Wix::Event's catalog payload into School/Trip create/update/
# deactivate side effects, mirroring the Nest wix-webhook-event-handler.service.ts
# behavior. Re-fetches canonical state from the Wix API rather than trusting the
# webhook payload as gospel (rails-dev references/webhooks.md).
class Wix::CatalogSync
  ALL_PRODUCTS_COLLECTION_ID = "00000000-000000-000000-000000000001"

  # Shared with Wix::PaymentSync, which also drift-heals School/Trip visibility
  # when auto-creating them from a payment's line items.
  def self.apply_visibility(record, visible)
    if visible == false
      record.conceal_in_store
    else
      record.activate if record.deactivated?
      record.reveal_in_store if record.store_concealed? && record.active?
    end
  end

  def initialize(event, client: Wix::Client.new)
    @event = event
    @payload = event.payload
    @client = client
  end

  def collection_created
    collection_id = @payload["collectionId"]
    return if School.exists?(wix_collection_id: collection_id)

    school = create_school(
      wix_collection_id: collection_id,
      title: @payload["name"].presence || collection_id,
      description: nil,
      image_url: Wix::Media.image_url(@payload["media"])
    )
    self.class.apply_visibility(school, @payload["visible"]) if school
  end

  def collection_changed
    collection_id = @payload["collectionId"]
    schools = School.where(wix_collection_id: collection_id)

    collection = fetch_collection(collection_id)
    return if collection.nil?

    if schools.none?
      heal_missing_school(collection_id, collection)
      return
    end

    schools.find_each do |school|
      school.update!(
        title: collection["name"].presence || school.title,
        description: collection["description"],
        image_url: Wix::Media.image_url(collection["media"])
      )
      self.class.apply_visibility(school, collection["visible"])
    end
  end

  def collection_deleted
    collection_id = @payload["collectionId"]

    School.where(wix_collection_id: collection_id).find_each do |school|
      if school.trips.joins(:passengers).exists?
        school.deactivate
        push_collection_visibility_false(collection_id)
      else
        school.destroy!
      end
    end
  end

  def product_created
    product_id = @payload["productId"]
    return if Trip.exists?(wix_product_id: product_id)

    product = fetch_product(product_id)
    return if product.nil?

    school = single_school_for_collections(product["collectionIds"])
    return if school.nil?

    trip = create_trip(school, product, product_id)
    self.class.apply_visibility(trip, product["visible"]) if trip
  end

  def product_changed
    product_id = @payload["productId"]
    trips = Trip.where(wix_product_id: product_id)

    if trips.none?
      drift_heal_product(product_id)
      return
    end

    product = fetch_product(product_id)
    return if product.nil?

    snapshot = Wix::ProductSnapshot.build(product, product_id)
    trips.find_each do |trip|
      trip.update!(snapshot)
      self.class.apply_visibility(trip, product["visible"])
    end
  end

  def product_deleted
    product_id = @payload["productId"]

    Trip.where(wix_product_id: product_id).find_each do |trip|
      if trip.passengers.exists?
        trip.deactivate
        push_product_visibility_false(product_id)
      else
        trip.destroy!
      end
    end
  end

  private
    def fetch_collection(collection_id)
      @client.get_collection(collection_id)
    rescue Wix::Client::ApiKeyMissing
      nil
    end

    def fetch_product(product_id)
      @client.get_product(product_id)
    rescue Wix::Client::ApiKeyMissing, Wix::Client::NotFound
      nil
    end

    def create_school(attrs)
      School.create!(attrs)
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      nil
    end

    def create_school_from_collection(collection_id, collection)
      school = create_school(
        wix_collection_id: collection_id,
        title: collection["name"].presence || collection_id,
        description: collection["description"],
        image_url: Wix::Media.image_url(collection["media"])
      )
      self.class.apply_visibility(school, collection["visible"]) if school
      school || School.find_by(wix_collection_id: collection_id)
    end

    def heal_missing_school(collection_id, collection)
      create_school_from_collection(collection_id, collection)
    end

    def push_collection_visibility_false(collection_id)
      @client.update_collection(collection_id, visible: false)
    rescue Wix::Client::Error
      nil
    end

    def push_product_visibility_false(product_id)
      @client.update_product(product_id, visible: false)
    rescue Wix::Client::Error
      nil
    end

    def single_school_for_collections(collection_ids)
      schools = School.where(wix_collection_id: Array(collection_ids))
      schools.count == 1 ? schools.first : nil
    end

    def create_trip(school, product, product_id)
      school.trips.create!(Wix::ProductSnapshot.build(product, product_id).merge(wix_product_id: product_id))
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      nil
    end

    def drift_heal_product(product_id)
      product = fetch_product(product_id)
      return if product.nil?

      collection_ids = Array(product["collectionIds"]) - [ ALL_PRODUCTS_COLLECTION_ID ]
      schools = School.where(wix_collection_id: collection_ids)
      return if schools.count > 1

      school = schools.first || resolve_school_for_drift_heal(collection_ids)
      return if school.nil?

      trip = create_trip(school, product, product_id)
      self.class.apply_visibility(trip, product["visible"]) if trip
    end

    def resolve_school_for_drift_heal(collection_ids)
      return nil if collection_ids.size != 1

      collection = fetch_collection(collection_ids.first)
      return nil if collection.nil?

      create_school_from_collection(collection_ids.first, collection)
    end
end
