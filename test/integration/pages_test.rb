require "test_helper"

class PagesTest < ActionDispatch::IntegrationTest
  test "redirects unauthenticated users from root to login (default-deny)" do
    get root_path
    assert_redirected_to new_session_path
  end

  test "redirects unauthenticated users from about to login (default-deny)" do
    get about_path
    assert_redirected_to new_session_path
  end
end
