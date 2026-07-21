require "test_helper"

class Webhooks::WixTest < ActionDispatch::IntegrationTest
  setup do
    @rsa_key = OpenSSL::PKey::RSA.generate(2048)
    WixIntegration.instance.update!(public_key: @rsa_key.public_key.to_pem)
  end

  test "does not require authentication and ingests a validly signed event" do
    envelope = { eventType: Wix::Event::COLLECTION_CREATED, data: { collectionId: "collection-int" }.to_json }.to_json
    jwt = JWT.encode({ data: envelope }, @rsa_key, "RS256")

    assert_difference "Wix::Event.count", 1 do
      post webhooks_wix_path, params: jwt
    end

    assert_response :ok
    event = Wix::Event.last
    assert_equal Wix::Event::COLLECTION_CREATED, event.event_type
    assert_equal "collection-int", event.wix_entity_id
  end

  test "returns unauthorized for a JWT that fails signature verification" do
    other_key = OpenSSL::PKey::RSA.generate(2048)
    jwt = JWT.encode({ data: { eventType: Wix::Event::COLLECTION_CREATED, data: "{}" }.to_json }, other_key, "RS256")

    assert_no_difference "Wix::Event.count" do
      post webhooks_wix_path, params: jwt
    end

    assert_response :unauthorized
  end

  test "returns unauthorized when no public key is configured" do
    WixIntegration.instance.update!(public_key: nil)
    jwt = JWT.encode({ data: { eventType: Wix::Event::COLLECTION_CREATED, data: "{}" }.to_json }, @rsa_key, "RS256")

    post webhooks_wix_path, params: jwt

    assert_response :unauthorized
  end

  test "returns bad_request for a validly signed but malformed envelope" do
    jwt = JWT.encode({ data: "not-json" }, @rsa_key, "RS256")

    assert_no_difference "Wix::Event.count" do
      post webhooks_wix_path, params: jwt
    end

    assert_response :bad_request
  end
end
