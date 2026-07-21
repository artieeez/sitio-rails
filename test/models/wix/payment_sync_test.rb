require "test_helper"

class Wix::PaymentSyncTest < ActiveSupport::TestCase
  class FakeClient
    def initialize(orders: {}, products: {}, collections: {}, order_error: nil)
      @orders = orders
      @products = products
      @collections = collections
      @order_error = order_error
    end

    def get_order(id)
      raise @order_error if @order_error

      @orders[id]
    end

    def get_product(id) = @products[id]
    def get_collection(id) = @collections[id]
  end

  SUB_EVENT_KEYS = {
    "TRANSACTION_CREATED" => "transactionCreatedEvent",
    "TRANSACTION_UPDATED" => "transactionUpdatedEvent",
    "TRANSACTION_STATUS_CHANGED" => "transactionStatusChangedEvent"
  }.freeze

  def payment_event_payload(order_id:, sub_event: "TRANSACTION_CREATED", amount: 150.0, provider_transaction_id: "txn-1", created_at: "2026-07-01T12:00:00.000Z")
    {
      "eventType" => sub_event,
      SUB_EVENT_KEYS.fetch(sub_event) => {
        "transaction" => {
          "verticalOrderId" => order_id,
          "amount" => { "amount" => amount, "currency" => "BRL" },
          "providerTransactionId" => provider_transaction_id,
          "createdAt" => created_at,
          "status" => "APPROVED"
        }
      }
    }
  end

  def order_with_student_fields(product_ids:, student_name: "Nova Aluna", student_cpf: "111.222.333-96", parent_first: "Ana", parent_last: "Silva", parent_phone: "51999999999", parent_email: "ana@example.com")
    {
      "id" => "order-1",
      "lineItems" => Array(product_ids).map { |id| { "catalogReference" => { "catalogItemId" => id } } },
      "extendedFields" => { "namespaces" => { "_user_fields" => { "student_name" => student_name, "student_cpf" => student_cpf }.compact } },
      "billingInfo" => { "contactDetails" => { "firstName" => parent_first, "lastName" => parent_last, "phone" => parent_phone, "email" => parent_email } },
      "buyerInfo" => { "email" => "buyer@example.com" }
    }
  end

  def sync_for(payload, client:)
    event = Wix::Event.new(event_type: Wix::Event::PAYMENT_EVENT, wix_entity_id: "", payload: payload)
    Wix::PaymentSync.new(event, client: client)
  end

  test "call creates a passenger and a payment from a TRANSACTION_CREATED event" do
    trip = trips(:active)
    order = order_with_student_fields(product_ids: [ trip.wix_product_id ])
    client = FakeClient.new(orders: { "order-1" => order })
    sync = sync_for(payment_event_payload(order_id: "order-1"), client: client)

    assert_difference [ "Passenger.count", "Payment.count" ], 1 do
      sync.call
    end

    passenger = Passenger.find_by!(trip_id: trip.id, cpf_normalized: "11122233396")
    assert_equal "Nova Aluna", passenger.full_name
    assert_equal "Ana Silva", passenger.parent_name
    assert_equal "51999999999", passenger.parent_phone_number
    assert_equal "ana@example.com", passenger.parent_email

    payment = passenger.payments.find_by!(wix_transaction_id: "txn-1")
    assert_equal 15_000, payment.amount_minor
    assert_equal "wix", payment.location
    assert_equal Date.new(2026, 7, 1), payment.paid_on
    assert_equal "Ana Silva", payment.payer_identity
  end

  test "call is idempotent — redelivering the same transaction does not duplicate the passenger or payment" do
    trip = trips(:active)
    order = order_with_student_fields(product_ids: [ trip.wix_product_id ])
    client = FakeClient.new(orders: { "order-1" => order })
    payload = payment_event_payload(order_id: "order-1")

    sync_for(payload, client: client).call

    assert_no_difference [ "Passenger.count", "Payment.count" ] do
      sync_for(payload, client: client).call
    end
  end

  test "call matches an existing passenger by CPF instead of creating a duplicate" do
    trip = trips(:active)
    passenger = passengers(:maria)
    order = order_with_student_fields(product_ids: [ trip.wix_product_id ], student_cpf: passenger.cpf_normalized)
    client = FakeClient.new(orders: { "order-1" => order })
    sync = sync_for(payment_event_payload(order_id: "order-1"), client: client)

    assert_no_difference "Passenger.count" do
      assert_difference "Payment.count", 1 do
        sync.call
      end
    end

    assert passenger.payments.exists?(wix_transaction_id: "txn-1")
  end

  test "call skips creating a payment for a passenger who was removed" do
    trip = trips(:active)
    removed = passengers(:removed)
    order = order_with_student_fields(product_ids: [ trip.wix_product_id ], student_cpf: removed.cpf_normalized)
    client = FakeClient.new(orders: { "order-1" => order })
    sync = sync_for(payment_event_payload(order_id: "order-1"), client: client)

    assert_no_difference [ "Passenger.count", "Payment.count" ] do
      sync.call
    end
  end

  test "call falls back to line item custom text fields when the order has no student_name" do
    trip = trips(:active)
    order = {
      "id" => "order-1",
      "lineItems" => [
        {
          "catalogReference" => {
            "catalogItemId" => trip.wix_product_id,
            "options" => {
              "customTextFields" => {
                "Nome completo e CPF do(a) aluno(a)" => "Fallback Aluno",
                "Nome completo e CPF do(a) responsável:" => "Fallback Responsável"
              }
            }
          }
        }
      ]
    }
    client = FakeClient.new(orders: { "order-1" => order })
    sync = sync_for(payment_event_payload(order_id: "order-1"), client: client)

    assert_difference [ "Passenger.count", "Payment.count" ], 1 do
      sync.call
    end

    passenger = Passenger.find_by!(trip_id: trip.id, full_name: "Fallback Aluno")
    assert_nil passenger.cpf_normalized
    assert_equal "Fallback Responsável", passenger.parent_name
  end

  test "call is a no-op when there is no student info anywhere in the order" do
    trip = trips(:active)
    order = { "id" => "order-1", "lineItems" => [ { "catalogReference" => { "catalogItemId" => trip.wix_product_id } } ] }
    client = FakeClient.new(orders: { "order-1" => order })
    sync = sync_for(payment_event_payload(order_id: "order-1"), client: client)

    assert_no_difference [ "Passenger.count", "Payment.count" ] do
      sync.call
    end
  end

  test "call auto-creates School and Trip when the product has no local trip yet" do
    order = order_with_student_fields(product_ids: [ "product-payment-drift" ])
    client = FakeClient.new(
      orders: { "order-1" => order },
      products: { "product-payment-drift" => { "name" => "Passeio Drift", "collectionIds" => [ "collection-payment-drift" ] } },
      collections: { "collection-payment-drift" => { "name" => "Escola Drift", "visible" => true } }
    )
    sync = sync_for(payment_event_payload(order_id: "order-1"), client: client)

    assert_difference [ "School.count", "Trip.count", "Passenger.count", "Payment.count" ], 1 do
      sync.call
    end

    trip = Trip.find_by!(wix_product_id: "product-payment-drift")
    assert_equal "Passeio Drift", trip.title
    assert_equal "Escola Drift", trip.school.title
  end

  test "call pays only the passenger for the order's first line item" do
    other_trip = schools(:active).trips.create!(title: "Segunda Viagem", wix_product_id: "product-second")
    trip = trips(:active)
    order = order_with_student_fields(product_ids: [ trip.wix_product_id, other_trip.wix_product_id ])
    client = FakeClient.new(orders: { "order-1" => order })
    sync = sync_for(payment_event_payload(order_id: "order-1"), client: client)

    assert_difference "Passenger.count", 2 do
      assert_difference "Payment.count", 1 do
        sync.call
      end
    end

    assert Passenger.exists?(trip_id: trip.id, cpf_normalized: "11122233396")
    assert Passenger.exists?(trip_id: other_trip.id, cpf_normalized: "11122233396")
  end

  test "call is a no-op for an unknown PaymentEvent sub-type" do
    sync = sync_for({ "eventType" => "REFUND_CREATED" }, client: FakeClient.new)

    assert_nothing_raised { sync.call }
  end

  test "call is a no-op when the transaction is missing verticalOrderId" do
    payload = { "eventType" => "TRANSACTION_CREATED", "transactionCreatedEvent" => { "transaction" => {} } }
    sync = sync_for(payload, client: FakeClient.new)

    assert_nothing_raised { sync.call }
  end

  test "call skips silently when the Wix API key is not configured" do
    client = FakeClient.new(order_error: Wix::Client::ApiKeyMissing.new)
    sync = sync_for(payment_event_payload(order_id: "order-1"), client: client)

    assert_nothing_raised { sync.call }
  end

  test "call re-raises non-ApiKeyMissing errors fetching the order" do
    client = FakeClient.new(order_error: Wix::Client::UpstreamError.new("boom"))
    sync = sync_for(payment_event_payload(order_id: "order-1"), client: client)

    assert_raises(Wix::Client::UpstreamError) { sync.call }
  end

  test "call skips creating a payment when the transaction amount is zero" do
    trip = trips(:active)
    order = order_with_student_fields(product_ids: [ trip.wix_product_id ])
    client = FakeClient.new(orders: { "order-1" => order })
    sync = sync_for(payment_event_payload(order_id: "order-1", amount: 0), client: client)

    assert_difference "Passenger.count", 1 do
      assert_no_difference "Payment.count" do
        sync.call
      end
    end
  end

  test "call is a no-op when the order has no line items with catalog references" do
    client = FakeClient.new(orders: { "order-1" => { "id" => "order-1", "lineItems" => [] } })
    sync = sync_for(payment_event_payload(order_id: "order-1"), client: client)

    assert_no_difference [ "Passenger.count", "Payment.count" ] do
      sync.call
    end
  end
end
