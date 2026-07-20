class Trip < ApplicationRecord
  include Deactivatable
  include StoreConcealable

  belongs_to :school, touch: true
  has_many :passengers, dependent: :destroy

  normalizes :wix_product_id, :wix_product_slug, :wix_product_page_url, :wix_media_file_id, :image_url, with: ->(value) {
    if value.blank?
      nil
    else
      value.strip
    end
  }

  validates :title, length: { maximum: 2000 }, allow_nil: true
  validates :description, length: { maximum: 8000 }, allow_nil: true
  validates :wix_product_id, length: { maximum: 128 }, uniqueness: true, allow_nil: true
  validates :image_url, :wix_product_page_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_nil: true
  validates :default_expected_amount_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true

  scope :ordered_by_title, -> { order(Arel.sql("LOWER(COALESCE(title, '')) ASC")) }
  scope :expired_for_store, -> {
    store_visible.where.not(expiration_date: nil).where(expiration_date: ...Time.current)
  }

  def self.listed(include_inactive: false)
    if include_inactive
      ordered_by_title
    else
      active.ordered_by_title
    end
  end

  def self.conceal_expired_in_store_now
    expired_for_store.find_each(&:conceal_in_store)
  end

  def self.conceal_expired_in_store_later
    Trip::ConcealExpiredInStoreJob.perform_later
  end

  def deletion = Trip::Deletion.new(self)

  def display_title
    if title.present?
      title
    else
      "Viagem ##{id}"
    end
  end
end
