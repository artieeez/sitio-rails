class Passenger < ApplicationRecord
  include Passenger::Removable
  include Passenger::ManuallySettlable

  belongs_to :trip, touch: true

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
    expected_amount_override_minor.presence || trip.default_expected_amount_minor
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
