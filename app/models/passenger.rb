class Passenger < ApplicationRecord
  PENDING = "pending"
  SETTLED_PAYMENTS = "settled_payments"
  SETTLED_MANUAL = "settled_manual"
  UNAVAILABLE = "unavailable"
  PAYMENT_STATUSES = [ PENDING, SETTLED_PAYMENTS, SETTLED_MANUAL, UNAVAILABLE ].freeze

  include Passenger::Removable
  include Passenger::ManuallySettlable

  belongs_to :trip, touch: true
  has_many :payments, dependent: :destroy

  attr_accessor :cpf, :confirm_name_duplicate

  before_validation :normalize_cpf_from_accessor
  before_validation :normalize_parent_phone

  validates :full_name, presence: true
  validates :cpf_normalized, uniqueness: { scope: :trip_id }, allow_nil: true
  validates :parent_email, format: { with: URI::MailTo::EMAIL_REGEXP }, allow_nil: true
  validates :expected_amount_override_minor, numericality: { only_integer: true, greater_than_or_equal_to: 0 }, allow_nil: true
  validate :cpf_must_be_valid
  validate :warn_duplicate_name_on_trip

  scope :listed, ->(include_removed: false) {
    if include_removed
      order(:full_name)
    else
      present.order(:full_name)
    end
  }

  def cpf_display = Cpf.format(cpf_normalized)

  def expected_amount_minor
    if expected_amount_override_minor != nil
      expected_amount_override_minor
    else
      trip.default_expected_amount_minor
    end
  end

  def paid_total_minor
    if payments.loaded?
      payments.sum(&:amount_minor)
    else
      payments.sum(:amount_minor)
    end
  end

  def payment_status
    if manually_settled?
      SETTLED_MANUAL
    elsif expected_amount_minor != nil
      if paid_total_minor >= expected_amount_minor
        SETTLED_PAYMENTS
      else
        PENDING
      end
    else
      UNAVAILABLE
    end
  end

  def payment_status_label
    case payment_status
    when SETTLED_MANUAL then "Pago (manual)"
    when SETTLED_PAYMENTS then "Pago"
    when PENDING then "Pendente"
    else "Indisponível"
    end
  end

  def normalized_full_name
    full_name.to_s.unicode_normalize(:nfkc).gsub(/\s+/, " ").strip.downcase
  end

  private
    def normalize_cpf_from_accessor
      return if cpf.nil?

      if cpf.blank?
        self.cpf_normalized = nil
      else
        self.cpf_normalized = Cpf.normalize(cpf)
      end
    rescue Cpf::Invalid
      @cpf_invalid = true
      self.cpf_normalized = nil
    end

    def normalize_parent_phone
      return if parent_phone_number.nil?

      digits = parent_phone_number.to_s.gsub(/\D/, "")
      self.parent_phone_number = digits.presence
    end

    def cpf_must_be_valid
      errors.add(:cpf, "is invalid") if @cpf_invalid
    end

    def warn_duplicate_name_on_trip
      return if full_name.blank?
      return if ActiveModel::Type::Boolean.new.cast(confirm_name_duplicate)

      duplicate = trip.passengers
        .where.not(id: id)
        .find { |passenger| passenger.normalized_full_name == normalized_full_name }

      if duplicate
        errors.add(:full_name, "already exists on this trip — confirm to proceed")
      end
    end
end
