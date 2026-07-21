require "test_helper"

class WixIntegrationTest < ActiveSupport::TestCase
  setup do
    @integration = wix_integrations(:unconfigured)
  end

  test "instance finds or creates the singleton row" do
    assert_equal @integration, WixIntegration.instance
    assert_equal 1, WixIntegration.instance.id
  end

  test "resolve_site_id prefers ENV over the stored value" do
    @integration.update!(site_id: "db-site")

    with_env("WIX_SITE_ID" => "env-site") do
      assert_equal "env-site", @integration.resolve_site_id
    end
  end

  test "resolve_site_id falls back to the stored value when ENV is unset" do
    @integration.update!(site_id: "db-site")

    with_env("WIX_SITE_ID" => nil) do
      assert_equal "db-site", @integration.resolve_site_id
    end
  end

  test "resolve_private_api_key prefers ENV over the stored value" do
    @integration.update!(private_api_key: "db-key")

    with_env("WIX_PRIVATE_API_KEY" => "env-key") do
      assert_equal "env-key", @integration.resolve_private_api_key
    end
  end

  test "resolve_public_key prefers ENV over the stored value" do
    @integration.update!(public_key: "-----BEGIN PUBLIC KEY-----\nZm9v\n-----END PUBLIC KEY-----")

    with_env("WIX_PUBLIC_KEY" => "env-key") do
      assert_equal "env-key", @integration.resolve_public_key
    end
  end

  test "private_api_key_prefix returns the first 10 characters" do
    with_env("WIX_PRIVATE_API_KEY" => "abcdefghijklmnop") do
      assert_equal "abcdefghij", @integration.private_api_key_prefix
    end
  end

  test "private_api_key_prefix is nil when no key is configured" do
    with_env("WIX_PRIVATE_API_KEY" => nil) do
      assert_nil @integration.private_api_key_prefix
    end
  end

  test "normalizes a public key without PEM markers into canonical PEM" do
    @integration.update!(public_key: "  Zm9vYmFy  ")

    assert_equal "-----BEGIN PUBLIC KEY-----\nZm9vYmFy\n-----END PUBLIC KEY-----", @integration.public_key
  end

  test "normalizes a public key with broken PEM markers into canonical PEM" do
    @integration.update!(public_key: "-----BEGIN PUBLIC KEY-----Zm9vYmFy-----END PUBLIC KEY-----")

    assert_equal "-----BEGIN PUBLIC KEY-----\nZm9vYmFy\n-----END PUBLIC KEY-----", @integration.public_key
  end

  test "normalizes blank credentials to nil" do
    @integration.update!(site_id: "  ", public_key: "  ", private_api_key: "  ")

    assert_nil @integration.site_id
    assert_nil @integration.public_key
    assert_nil @integration.private_api_key
  end

  private
    def with_env(vars)
      original = vars.keys.index_with { |key| ENV[key] }
      vars.each { |key, value| ENV[key] = value }
      yield
    ensure
      original.each { |key, value| ENV[key] = value }
    end
end
