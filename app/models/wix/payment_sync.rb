# Resolves a Cashier PaymentEvent webhook into Passenger/Payment records,
# mirroring onPaymentEvent + ensureCatalogEntitiesForOrder + createPassengersAndPayments
# in wix-webhook-event-handler.service.ts. Drift-heals School/Trip for every line
# item's product (like Wix::CatalogSync's *Changed path), then matches/creates a
# Passenger per line item by CPF, but — matching Nest — only creates one Payment
# per transaction, for the order's first line item, deduped by wix_transaction_id.
class Wix::PaymentSync
  ALL_PRODUCTS_COLLECTION_ID = Wix::CatalogSync::ALL_PRODUCTS_COLLECTION_ID

  TRANSACTION_EVENT_KEYS = {
    "TRANSACTION_CREATED" => "transactionCreatedEvent",
    "TRANSACTION_UPDATED" => "transactionUpdatedEvent",
    "TRANSACTION_STATUS_CHANGED" => "transactionStatusChangedEvent"
  }.freeze

  STUDENT_TEXT_FIELD = "Nome completo e CPF do(a) aluno(a)"
  PARENT_TEXT_FIELD = "Nome completo e CPF do(a) responsável:"

  def initialize(event, client: Wix::Client.new)
    @payload = event.payload
    @client = client
  end

  def call
    transaction = resolve_transaction
    return if transaction.nil?

    order_id = transaction.dig("transaction", "verticalOrderId")
    return if order_id.blank?

    order = fetch_order(order_id)
    return if order.nil?

    product_ids = product_ids_for(order)
    return if product_ids.empty?

    product_ids.each { |product_id| ensure_school_and_trip(product_id) }
    create_passengers_and_payments(order, product_ids, transaction)
  end

  private
    def resolve_transaction
      key = TRANSACTION_EVENT_KEYS[@payload["eventType"]]
      key && @payload[key]
    end

    def fetch_order(order_id)
      @client.get_order(order_id)
    rescue Wix::Client::ApiKeyMissing
      nil
    end

    def product_ids_for(order)
      Array(order["lineItems"]).filter_map { |item| item.dig("catalogReference", "catalogItemId").presence }
    end

    # Same shape as Wix::CatalogSync's product_changed drift-heal, except an
    # ambiguous school match resolves to the first school instead of skipping
    # (matches Nest's resolveOrCreateSchoolForPaymentProduct).
    def ensure_school_and_trip(product_id)
      return if Trip.exists?(wix_product_id: product_id)

      product = fetch_product(product_id)
      return if product.nil?

      collection_ids = Array(product["collectionIds"]) - [ ALL_PRODUCTS_COLLECTION_ID ]
      school = resolve_or_create_school(collection_ids)
      return if school.nil?

      create_trip(school, product, product_id)
    end

    def fetch_product(product_id)
      @client.get_product(product_id)
    rescue Wix::Client::ApiKeyMissing, Wix::Client::NotFound
      nil
    end

    def resolve_or_create_school(collection_ids)
      schools = School.where(wix_collection_id: collection_ids)
      return schools.first if schools.any?
      return nil if collection_ids.size != 1

      create_school_from_collection(collection_ids.first)
    end

    def create_school_from_collection(collection_id)
      collection = fetch_collection(collection_id)
      return nil if collection.nil?

      school = School.create!(
        wix_collection_id: collection_id,
        title: collection["name"].presence || collection_id,
        description: collection["description"],
        image_url: Wix::Media.image_url(collection["media"])
      )
      Wix::CatalogSync.apply_visibility(school, collection["visible"])
      school
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      School.find_by(wix_collection_id: collection_id)
    end

    def fetch_collection(collection_id)
      @client.get_collection(collection_id)
    rescue Wix::Client::ApiKeyMissing
      nil
    end

    def create_trip(school, product, product_id)
      trip = school.trips.create!(Wix::ProductSnapshot.build(product, product_id).merge(wix_product_id: product_id))
      Wix::CatalogSync.apply_visibility(trip, product["visible"])
      trip
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      nil
    end

    def create_passengers_and_payments(order, product_ids, transaction)
      student = resolve_student(order)
      return if student.nil?

      product_ids.each_with_index do |product_id, index|
        passenger = find_or_create_passenger(product_id, student)
        next if passenger.nil?
        next if index > 0 # Nest pays only the first line item's passenger per transaction.

        create_payment(passenger, transaction, student[:parent_name] || passenger.full_name)
      end
    end

    def resolve_student(order)
      custom_fields = order.dig("extendedFields", "namespaces", "_user_fields") || {}
      billing_contact = order.dig("billingInfo", "contactDetails") || {}

      student_name = custom_fields["student_name"]
      cpf_raw = custom_fields["student_cpf"]
      parent_name = billing_contact_full_name(billing_contact)
      parent_phone = billing_contact["phone"]
      parent_email = billing_contact["email"] || order.dig("buyerInfo", "email")

      if student_name.blank?
        student_name, parent_name = resolve_student_from_line_item(order, parent_name)
        return nil if student_name.nil?

        cpf_raw = nil
      end

      { student_name:, cpf_normalized: normalize_order_cpf(cpf_raw), parent_name:, parent_phone:, parent_email: }
    end

    def billing_contact_full_name(billing_contact)
      first_name = billing_contact["firstName"]
      last_name = billing_contact["lastName"]
      return nil if first_name.blank? || last_name.blank?

      "#{first_name} #{last_name}".strip
    end

    # Falls back to the line item's free-text checkout field when the order has
    # no structured student_name custom field (matches Nest's fallback + needsReview).
    def resolve_student_from_line_item(order, parent_name)
      custom_text_fields = order.dig("lineItems", 0, "catalogReference", "options", "customTextFields") || {}
      raw_student = custom_text_fields[STUDENT_TEXT_FIELD]
      return [ nil, nil ] if raw_student.blank?

      [ raw_student, parent_name || custom_text_fields[PARENT_TEXT_FIELD] ]
    end

    def normalize_order_cpf(raw)
      Cpf.normalize(raw)
    rescue Cpf::Invalid
      nil
    end

    def find_or_create_passenger(product_id, student)
      trip = Trip.find_by(wix_product_id: product_id)
      return nil if trip.nil?

      find_by_cpf(trip, student[:cpf_normalized]) || create_passenger(trip, student)
    end

    def find_by_cpf(trip, cpf_normalized)
      return nil if cpf_normalized.nil?

      Passenger.find_by(trip_id: trip.id, cpf_normalized:)
    end

    def create_passenger(trip, student)
      Passenger.create!(
        trip_id: trip.id,
        full_name: student[:student_name].strip,
        cpf_normalized: student[:cpf_normalized],
        parent_name: student[:parent_name],
        parent_phone_number: student[:parent_phone],
        parent_email: student[:parent_email],
        confirm_name_duplicate: true
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      find_by_cpf(trip, student[:cpf_normalized])
    end

    # Passenger removal has no Nest equivalent; skip instead of letting the
    # Payment validation raise and fail the whole webhook delivery.
    def create_payment(passenger, transaction, payer_identity)
      return if passenger.removed?

      tx = transaction["transaction"] || {}
      transaction_id = tx["providerTransactionId"].presence
      return if transaction_id && Payment.exists?(wix_transaction_id: transaction_id)

      amount = tx.dig("amount", "amount")
      return if amount.nil? || amount.to_f <= 0

      Payment.create!(
        passenger_id: passenger.id,
        amount_minor: (amount.to_f * 100).round,
        paid_on: paid_on_for(tx),
        location: "wix",
        payer_identity:,
        wix_transaction_id: transaction_id
      )
    rescue ActiveRecord::RecordInvalid, ActiveRecord::RecordNotUnique
      nil
    end

    def paid_on_for(tx)
      created_at = tx["createdAt"]
      created_at.present? ? Date.parse(created_at.split("T").first) : Date.current
    end
end
