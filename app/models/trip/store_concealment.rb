class Trip::StoreConcealment < ApplicationRecord
  belongs_to :trip, touch: true
  belongs_to :user, optional: true

  validates :trip, uniqueness: true
end
