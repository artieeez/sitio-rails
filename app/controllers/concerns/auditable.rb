# Records an AuditLog entry for every mutating request (POST/PATCH/PUT/DELETE),
# including unauthenticated ones like inbound webhooks (actor "system"). GETs
# and the health check are never mutating, so they're skipped without a
# separate guard. A failure to write the log never breaks the request.
module Auditable
  extend ActiveSupport::Concern

  MUTATING_METHODS = %w[ POST PATCH PUT DELETE ].freeze

  included do
    after_action :record_audit_log, if: :mutating_request?
  end

  private
    def mutating_request? = MUTATING_METHODS.include?(request.method)

    def record_audit_log
      AuditLog.record(user: Current.user, action: request.method, resource: request.path, ip_address: request.remote_ip)
    rescue => e
      Rails.error.report(e, handled: true, context: { path: request.path, method: request.method })
    end
end
