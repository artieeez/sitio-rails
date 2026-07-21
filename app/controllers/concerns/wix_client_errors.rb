module WixClientErrors
  extend ActiveSupport::Concern

  included do
    # rescue_from handlers are searched most-recently-declared first, so the
    # most specific classes must be declared last.
    rescue_from Wix::Client::Error do |e|
      render_wix_error "wix_upstream_error", :bad_gateway, e.message
    end
    rescue_from Wix::Client::NotFound do
      render_wix_error "not_found", :not_found, "Not found in Wix"
    end
    rescue_from Wix::Client::ApiKeyMissing do
      render_wix_error "wix_not_configured", :service_unavailable, "Wix API key is not configured"
    end
  end

  private
    def render_wix_error(code, status, message)
      render json: { code:, message: }, status:
    end
end
