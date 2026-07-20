class Payment < ApplicationRecord
  belongs_to :passenger, touch: true

  before_validation :normalize_text_fields

  validates :amount_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :paid_on, presence: true
  validates :location, presence: true
  validates :payer_identity, presence: true
  validates :wix_transaction_id, uniqueness: true, allow_nil: true
  validate :passenger_must_accept_payments, on: :create

  scope :chronological, -> { order(:paid_on, :created_at) }

  private
    def normalize_text_fields
      self.location = location.to_s.strip.presence
      self.payer_identity = payer_identity.to_s.strip.presence
      self.wix_transaction_id = wix_transaction_id.to_s.strip.presence
    end

    def passenger_must_accept_payments
      return if passenger.blank?
      return unless passenger.removed?

      errors.add(:passenger, "was removed")
    end
end
