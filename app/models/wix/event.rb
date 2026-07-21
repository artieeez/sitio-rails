# Inbox for inbound Wix webhook deliveries (catalog + payment events). Persist
# first, ack fast, process in the background (rails-dev references/webhooks.md).
class Wix::Event < ApplicationRecord
  self.table_name = "wix_events"

  COLLECTION_CREATED = "com.wix.ecommerce.catalog.api.v1.CollectionCreated"
  COLLECTION_CHANGED = "com.wix.ecommerce.catalog.api.v1.CollectionChanged"
  COLLECTION_DELETED = "com.wix.ecommerce.catalog.api.v1.CollectionDeleted"
  PRODUCT_CREATED = "com.wix.ecommerce.catalog.api.v1.ProductCreated"
  PRODUCT_CHANGED = "com.wix.ecommerce.catalog.api.v1.ProductChanged"
  PRODUCT_DELETED = "com.wix.ecommerce.catalog.api.v1.ProductDeleted"
  PAYMENT_EVENT = "com.wix.payment.api.pay.v3.PaymentEvent"

  CATALOG_SYNC_DISPATCH = {
    COLLECTION_CREATED => :collection_created,
    COLLECTION_CHANGED => :collection_changed,
    COLLECTION_DELETED => :collection_deleted,
    PRODUCT_CREATED => :product_created,
    PRODUCT_CHANGED => :product_changed,
    PRODUCT_DELETED => :product_deleted
  }.freeze

  DESCRIPTIONS = {
    COLLECTION_CREATED => "Coleção criada",
    COLLECTION_CHANGED => "Coleção alterada",
    COLLECTION_DELETED => "Coleção removida",
    PRODUCT_CREATED => "Produto criado",
    PRODUCT_CHANGED => "Produto alterado",
    PRODUCT_DELETED => "Produto removido",
    PAYMENT_EVENT => "Evento de pagamento"
  }.freeze

  validates :event_type, presence: true

  scope :pending, -> { where(processed_at: nil, failed_at: nil) }
  scope :processed, -> { where.not(processed_at: nil) }
  scope :failed, -> { where.not(failed_at: nil) }

  after_create_commit :process_later

  def self.ingest(event_type:, data:)
    wix_entity_id = data["productId"] || data["collectionId"] || data["entityId"] || ""
    create!(event_type:, wix_entity_id:, payload: data)
  end

  def process_later = Wix::ProcessEventJob.perform_later(self)

  def process_now
    return if processed?

    update!(claimed_at: Time.current) if claimed_at.nil?
    dispatch
    update!(processed_at: Time.current)
  rescue => e
    update!(last_error: e.message, attempts: attempts + 1)
    raise
  end

  def mark_failed(error) = update!(failed_at: Time.current, last_error: error.message)

  def processed? = processed_at.present?
  def failed? = failed_at.present?
  def description = DESCRIPTIONS[event_type] || event_type

  private
    def dispatch
      if event_type == PAYMENT_EVENT
        Wix::PaymentSync.new(self).call
      elsif (method = CATALOG_SYNC_DISPATCH[event_type])
        Wix::CatalogSync.new(self).public_send(method)
      else
        Rails.logger.warn("Unknown Wix webhook event type: #{event_type}")
      end
    end
end
