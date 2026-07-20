module Deactivatable
  extend ActiveSupport::Concern

  included do
    has_one :deactivation, class_name: "#{name}::Deactivation", dependent: :destroy

    scope :active, -> { where.missing(:deactivation) }
    scope :inactive, -> { joins(:deactivation) }
  end

  def deactivate(user: Current.user)
    transaction do
      create_deactivation!(user:) unless deactivated?
      conceal_in_store(user:)
    end
  end

  def activate
    deactivation&.destroy!
    association(:deactivation).reset
  end

  def deactivated? = deactivation.present?
  def active? = !deactivated?
  def deactivated_at = deactivation&.created_at
  def deactivated_by = deactivation&.user
end
