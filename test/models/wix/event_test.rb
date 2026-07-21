require "test_helper"

class Wix::EventTest < ActiveSupport::TestCase
  include ActiveJob::TestHelper

  setup do
    @pending = wix_events(:pending)
    @processed = wix_events(:processed)
    @failed = wix_events(:failed)
  end

  test "ingest resolves the wix entity id from the payload and enqueues processing" do
    assert_enqueued_with job: Wix::ProcessEventJob do
      Wix::Event.ingest(event_type: Wix::Event::PRODUCT_CREATED, data: { "productId" => "product-9" })
    end
  end

  test "ingest defaults wix_entity_id to an empty string when unresolvable" do
    event = Wix::Event.ingest(event_type: Wix::Event::PAYMENT_EVENT, data: { "id" => "payment-event-1" })

    assert_equal "", event.wix_entity_id
  end

  test "pending scope excludes processed and failed events" do
    assert_includes Wix::Event.pending, @pending
    assert_not_includes Wix::Event.pending, @processed
    assert_not_includes Wix::Event.pending, @failed
  end

  test "processed? and failed? reflect their timestamps" do
    assert_not @pending.processed?
    assert @processed.processed?
    assert @failed.failed?
  end

  test "process_now dispatches to Wix::CatalogSync and marks the event processed" do
    called = false

    with_catalog_sync_stubbed(:collection_created, -> { called = true }) do
      @pending.process_now
    end

    assert called
    assert @pending.processed?
    assert @pending.claimed_at.present?
  end

  test "process_now dispatches PAYMENT_EVENT to Wix::PaymentSync" do
    payment_event = wix_events(:pending)
    payment_event.update!(event_type: Wix::Event::PAYMENT_EVENT)
    called = false

    with_payment_sync_stubbed(-> { called = true }) do
      payment_event.process_now
    end

    assert called
    assert payment_event.processed?
  end

  test "process_now is a no-op when already processed" do
    with_catalog_sync_stubbed(:collection_changed, -> { raise "should not be called" }) do
      assert_nothing_raised { @processed.process_now }
    end
  end

  test "process_now records the error and re-raises when the handler fails" do
    with_catalog_sync_stubbed(:collection_created, -> { raise "boom" }) do
      assert_raises(RuntimeError) { @pending.process_now }
    end

    assert_equal "boom", @pending.last_error
    assert_equal 1, @pending.attempts
    assert_not @pending.processed?
  end

  test "process_now no-ops on an unknown event type but still marks processed" do
    @pending.update!(event_type: "com.wix.unknown.EventType")

    @pending.process_now

    assert @pending.processed?
  end

  test "mark_failed records a terminal failure" do
    @pending.mark_failed(RuntimeError.new("exhausted"))

    assert @pending.failed?
    assert_equal "exhausted", @pending.last_error
  end

  private
    def with_catalog_sync_stubbed(method_name, handler)
      original_new = Wix::CatalogSync.method(:new)
      fake = Object.new
      fake.define_singleton_method(method_name) { handler.call }
      Wix::CatalogSync.define_singleton_method(:new) { |*| fake }
      yield
    ensure
      Wix::CatalogSync.define_singleton_method(:new, original_new)
    end

    def with_payment_sync_stubbed(handler)
      original_new = Wix::PaymentSync.method(:new)
      fake = Object.new
      fake.define_singleton_method(:call) { handler.call }
      Wix::PaymentSync.define_singleton_method(:new) { |*| fake }
      yield
    ensure
      Wix::PaymentSync.define_singleton_method(:new, original_new)
    end
end
