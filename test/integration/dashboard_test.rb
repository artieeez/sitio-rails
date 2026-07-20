require "test_helper"

class DashboardTest < ActionDispatch::IntegrationTest
  setup { Rails.cache.clear }

  test "redirects unauthenticated users from root to login (default-deny)" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "member can see dashboard but not admin demo" do
    sign_in_as users(:member)

    get root_path
    assert_response :ok
    assert_includes response.body, "Dashboard"

    get dashboard_admin_demo_path
    assert_response :forbidden
  end

  test "admin can see admin demo" do
    sign_in_as users(:admin)

    get dashboard_admin_demo_path
    assert_response :ok
    assert_includes response.body, "Admin-only content"
  end
end
