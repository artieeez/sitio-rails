module Passenger::ManuallySettlable
  extend ActiveSupport::Concern

  included do
    has_one :manual_settlement, class_name: "Passenger::ManualSettlement", dependent: :destroy

    scope :manually_settled, -> { joins(:manual_settlement) }
    scope :not_manually_settled, -> { where.missing(:manual_settlement) }
  end

  def mark_manual_settlement(user: Current.user)
    create_manual_settlement!(user:) unless manually_settled?
  end

  def clear_manual_settlement
    manual_settlement&.destroy!
    association(:manual_settlement).reset
  end

  def manually_settled? = manual_settlement.present?
end
