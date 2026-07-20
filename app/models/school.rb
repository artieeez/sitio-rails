class School < ApplicationRecord
  include Deactivatable
  include StoreConcealable

  has_many :trips, dependent: :destroy

  normalizes :wix_collection_id, with: ->(value) {
    if value.blank?
      nil
    else
      value.strip
    end
  }
  normalizes :url, :image_url, :favicon_url, with: ->(value) {
    if value.blank?
      nil
    else
      value.strip
    end
  }

  validates :title, length: { maximum: 2000 }, allow_nil: true
  validates :description, length: { maximum: 8000 }, allow_nil: true
  validates :wix_collection_id, length: { maximum: 128 }, uniqueness: true, allow_nil: true
  validates :url, :image_url, :favicon_url, format: { with: URI::DEFAULT_PARSER.make_regexp(%w[http https]) }, allow_nil: true

  scope :ordered_by_title, -> { order(Arel.sql("LOWER(COALESCE(title, '')) ASC")) }

  def self.listed(include_inactive: false)
    if include_inactive
      ordered_by_title
    else
      active.ordered_by_title
    end
  end

  def deletion = School::Deletion.new(self)

  def display_title
    if title.present?
      title
    else
      "Escola ##{id}"
    end
  end
end
