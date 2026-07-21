module Admin
  class WixIntegrationsController < ApplicationController
    before_action :require_admin!

    def show
      @wix_integration = WixIntegration.instance
      @sites = fetch_sites
      @webhook_callback_url = webhook_callback_url
    end

    def update
      @wix_integration = WixIntegration.instance
      attributes = wix_integration_params
      attributes = attributes.except(:private_api_key) if attributes[:private_api_key].blank?

      if @wix_integration.update(attributes)
        redirect_to admin_wix_integration_path, notice: "Integração Wix atualizada."
      else
        @sites = fetch_sites
        @webhook_callback_url = webhook_callback_url
        render :show, status: :unprocessable_entity
      end
    end

    private
      def wix_integration_params
        params.require(:wix_integration).permit(:site_id, :public_key, :private_api_key)
      end

      def fetch_sites
        return [] if WixIntegration.instance.resolve_private_api_key.blank?

        Wix::Client.new.list_sites
      rescue Wix::Client::Error => e
        Rails.error.report(e, handled: true, context: { area: "admin_wix_integration_sites" })
        []
      end

      def webhook_callback_url
        "#{ENV["APP_BASE_URL"].presence || request.base_url}#{webhooks_wix_path}"
      end
  end
end
