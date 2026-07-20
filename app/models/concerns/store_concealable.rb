module StoreConcealable
  extend ActiveSupport::Concern

  class Error < StandardError; end
  class Inactive < Error; end

  included do
    has_one :store_concealment, class_name: "#{name}::StoreConcealment", dependent: :destroy

    scope :store_visible, -> { where.missing(:store_concealment) }
    scope :store_concealed, -> { joins(:store_concealment) }
  end

  def conceal_in_store(user: Current.user)
    create_store_concealment!(user:) unless store_concealed?
  end

  def reveal_in_store
    raise Inactive, "Cannot reveal an inactive #{model_name.human.downcase} in the store" if deactivated?

    store_concealment&.destroy!
    association(:store_concealment).reset
  end

  def store_concealed? = store_concealment.present?
  def store_visible? = !store_concealed?
  def store_concealed_at = store_concealment&.created_at
  def store_concealed_by = store_concealment&.user
end
