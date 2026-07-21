require "test_helper"

class AuditLogTest < ActiveSupport::TestCase
  test "record captures the acting user" do
    admin = users(:admin)

    assert_difference -> { AuditLog.count }, 1 do
      AuditLog.record(user: admin, action: "POST", resource: "/schools", ip_address: "127.0.0.1")
    end

    audit_log = AuditLog.recent.first
    assert_equal admin.id.to_s, audit_log.user_id
    assert_equal admin.email_address, audit_log.user_email
    assert_not audit_log.system?
  end

  test "record falls back to the system actor when there is no user" do
    AuditLog.record(user: nil, action: "POST", resource: "/webhooks/wix", ip_address: "203.0.113.7")

    audit_log = AuditLog.recent.first
    assert_equal AuditLog::SYSTEM_ACTOR, audit_log.user_id
    assert_nil audit_log.user_email
    assert audit_log.system?
  end

  test "recent orders newest first" do
    older = audit_logs(:admin_school_create)
    newer = audit_logs(:system_webhook)

    assert_equal [ newer, older ], AuditLog.recent.to_a
  end

  test "paginate limits to 100 records per page" do
    assert_equal 2, AuditLog.paginate(page: 1).count
    assert_equal 0, AuditLog.paginate(page: 2).count
  end

  test "requires action and resource" do
    audit_log = AuditLog.new(user_id: "1")

    assert_not audit_log.valid?
    assert_includes audit_log.errors.attribute_names, :action
    assert_includes audit_log.errors.attribute_names, :resource
  end
end
