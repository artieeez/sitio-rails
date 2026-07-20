class School::StoreConcealment < ApplicationRecord
  belongs_to :school, touch: true
  belongs_to :user, optional: true

  validates :school, uniqueness: true
end
