require "test_helper"

class Admin::AuditLogsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  test "index lists recent audit log entries" do
    get admin_audit_logs_url

    assert_response :success
    assert_match audit_logs(:system_webhook).resource, response.body
    assert_match audit_logs(:admin_school_create).resource, response.body
  end

  test "show renders a single entry" do
    get admin_audit_log_url(audit_logs(:admin_school_create))

    assert_response :success
    assert_match audit_logs(:admin_school_create).user_email, response.body
  end

  test "member is forbidden" do
    sign_out
    sign_in_as users(:member)

    get admin_audit_logs_url

    assert_response :forbidden
  end
end
