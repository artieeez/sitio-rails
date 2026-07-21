require "test_helper"

class AuditLoggingTest < ActionDispatch::IntegrationTest
  test "creating a school records an audit log entry for the acting admin" do
    admin = users(:admin)
    sign_in_as admin

    assert_difference -> { AuditLog.count }, 1 do
      post schools_url, params: { school: { title: "Nova Escola", url: "https://example.com/nova" } }
    end

    audit_log = AuditLog.recent.first
    assert_equal admin.id.to_s, audit_log.user_id
    assert_equal admin.email_address, audit_log.user_email
    assert_equal "POST", audit_log.action
    assert_equal "/schools", audit_log.resource
    assert_not audit_log.system?
  end

  test "a GET request does not record an audit log entry" do
    sign_in_as users(:admin)

    assert_no_difference -> { AuditLog.count } do
      get schools_url
    end
  end

  test "an inbound webhook records an audit log entry for the system actor" do
    rsa_key = OpenSSL::PKey::RSA.generate(2048)
    WixIntegration.instance.update!(public_key: rsa_key.public_key.to_pem)
    envelope = { eventType: Wix::Event::COLLECTION_CREATED, data: { collectionId: "collection-audit" }.to_json }.to_json
    jwt = JWT.encode({ data: envelope }, rsa_key, "RS256")

    assert_difference -> { AuditLog.count }, 1 do
      post webhooks_wix_path, params: jwt
    end

    audit_log = AuditLog.recent.first
    assert audit_log.system?
    assert_equal "POST", audit_log.action
    assert_equal "/webhooks/wix", audit_log.resource
  end

  test "a failed insert does not break the request" do
    sign_in_as users(:admin)

    with_broken_audit_log do
      post schools_url, params: { school: { title: "Nova Escola", url: "https://example.com/nova" } }
    end

    assert_response :redirect
  end

  private
    def with_broken_audit_log
      original_record = AuditLog.method(:record)
      AuditLog.define_singleton_method(:record) { |**| raise StandardError, "boom" }
      yield
    ensure
      AuditLog.define_singleton_method(:record, original_record)
    end
end
