class Passenger::ManualSettlement < ApplicationRecord
  belongs_to :passenger, touch: true
  belongs_to :user, optional: true

  validates :passenger, uniqueness: true
end
