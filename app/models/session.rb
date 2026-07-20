class Session < ApplicationRecord
  belongs_to :user

  before_validation :set_expires_at, on: :create

  private
    def set_expires_at
      self.expires_at ||= 14.days.from_now
    end
end
