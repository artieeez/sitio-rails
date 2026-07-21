require "test_helper"

class Wix::WebhookTest < ActiveSupport::TestCase
  setup do
    @rsa_key = OpenSSL::PKey::RSA.generate(2048)
    @integration = WixIntegration.new(public_key: @rsa_key.public_key.to_pem)
  end

  test "verifies and parses a valid Wix webhook JWT" do
    envelope = { eventType: Wix::Event::COLLECTION_CREATED, instanceId: "instance-1", data: { collectionId: "collection-1", name: "Escola" }.to_json }.to_json
    jwt = JWT.encode({ data: envelope }, @rsa_key, "RS256")

    event_type, data = Wix::Webhook.verify_and_parse(jwt, integration: @integration)

    assert_equal Wix::Event::COLLECTION_CREATED, event_type
    assert_equal "collection-1", data["collectionId"]
    assert_equal "Escola", data["name"]
  end

  test "raises InvalidSignature when the JWT was not signed with the configured key" do
    other_key = OpenSSL::PKey::RSA.generate(2048)
    envelope = { eventType: Wix::Event::COLLECTION_CREATED, data: {}.to_json }.to_json
    jwt = JWT.encode({ data: envelope }, other_key, "RS256")

    assert_raises(Wix::Webhook::InvalidSignature) do
      Wix::Webhook.verify_and_parse(jwt, integration: @integration)
    end
  end

  test "raises InvalidSignature when no public key is configured" do
    assert_raises(Wix::Webhook::InvalidSignature) do
      Wix::Webhook.verify_and_parse("anything", integration: WixIntegration.new)
    end
  end

  test "raises InvalidSignature for a malformed JWT string" do
    assert_raises(Wix::Webhook::InvalidSignature) do
      Wix::Webhook.verify_and_parse("not-a-jwt", integration: @integration)
    end
  end

  test "raises MalformedEnvelope when the JWT data claim is not a JSON object" do
    jwt = JWT.encode({ data: "not-json" }, @rsa_key, "RS256")

    assert_raises(Wix::Webhook::MalformedEnvelope) do
      Wix::Webhook.verify_and_parse(jwt, integration: @integration)
    end
  end

  test "returns an empty payload hash when the envelope data field is missing" do
    envelope = { eventType: Wix::Event::COLLECTION_DELETED }.to_json
    jwt = JWT.encode({ data: envelope }, @rsa_key, "RS256")

    event_type, data = Wix::Webhook.verify_and_parse(jwt, integration: @integration)

    assert_equal Wix::Event::COLLECTION_DELETED, event_type
    assert_equal({}, data)
  end
end
