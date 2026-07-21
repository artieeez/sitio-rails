require "test_helper"

class Admin::WixIntegrationsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  test "admin shows the integration settings" do
    get admin_wix_integration_url

    assert_response :success
  end

  test "admin updates the site id and public key" do
    patch admin_wix_integration_url, params: {
      wix_integration: { site_id: "site-123", public_key: "-----BEGIN PUBLIC KEY-----\nabc\n-----END PUBLIC KEY-----" }
    }

    assert_redirected_to admin_wix_integration_url
    assert_equal "site-123", WixIntegration.instance.site_id
  end

  test "blank private_api_key does not overwrite the stored key" do
    WixIntegration.instance.update!(private_api_key: "current-key")

    patch admin_wix_integration_url, params: { wix_integration: { site_id: "site-123", private_api_key: "" } }

    assert_equal "current-key", WixIntegration.instance.private_api_key
  end

  test "filled private_api_key rotates the stored key" do
    WixIntegration.instance.update!(private_api_key: "old-key")

    patch admin_wix_integration_url, params: { wix_integration: { private_api_key: "new-key" } }

    assert_equal "new-key", WixIntegration.instance.private_api_key
  end

  test "loads the site list when a private key is configured" do
    WixIntegration.instance.update!(private_api_key: "current-key")

    with_wix_client(FakeClient.new(sites: [ { "id" => "site-1", "displayName" => "Loja Principal" } ])) do
      get admin_wix_integration_url
    end

    assert_response :success
    assert_match "Loja Principal", response.body
  end

  test "member is forbidden" do
    sign_out
    sign_in_as users(:member)

    get admin_wix_integration_url

    assert_response :forbidden
  end

  class FakeClient
    def initialize(sites: [])
      @sites = sites
    end

    def list_sites = @sites
  end

  private
    def with_wix_client(fake_client)
      original_new = Wix::Client.method(:new)
      Wix::Client.define_singleton_method(:new) { |*, **| fake_client }
      yield
    ensure
      Wix::Client.define_singleton_method(:new, original_new)
    end
end
