module Passenger::Removable
  extend ActiveSupport::Concern

  included do
    has_one :removal, class_name: "Passenger::Removal", dependent: :destroy

    scope :present, -> { where.missing(:removal) }
    scope :removed, -> { joins(:removal) }
  end

  def remove(user: Current.user)
    create_removal!(user:) unless removed?
  end

  def restore
    removal&.destroy!
    association(:removal).reset
  end

  def removed? = removal.present?
  def removed_at = removal&.created_at
  def removed_by = removal&.user
end
