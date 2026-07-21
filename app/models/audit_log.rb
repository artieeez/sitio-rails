# Append-only record of every mutating request: who did it (or "system" for
# webhooks), which HTTP verb, and which resource path. No updated_at: an audit
# log entry is never revised after it is written.
class AuditLog < ApplicationRecord
  SYSTEM_ACTOR = "system"

  validates :user_id, :action, :resource, presence: true

  scope :recent, -> { order(created_at: :desc, id: :desc) }

  def self.paginate(page: 1)
    page = page.to_i
    page = 1 if page < 1
    recent.limit(100).offset((page - 1) * 100)
  end

  def self.record(user:, action:, resource:, ip_address:)
    create!(
      user_id: user&.id&.to_s || SYSTEM_ACTOR,
      user_email: user&.email_address,
      user_name: user&.email_address,
      action:,
      resource:,
      ip_address:
    )
  end

  def system? = user_id == SYSTEM_ACTOR
end
