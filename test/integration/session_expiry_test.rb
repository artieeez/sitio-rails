require "test_helper"

class SessionExpiryTest < ActionDispatch::IntegrationTest
  test "treats an expired session cookie as logged out" do
    sign_in_as users(:admin)
    assert_redirected_to root_path

    session_record = Session.last!
    session_record.update_column(:expires_at, 1.minute.ago)

    get root_path

    assert_redirected_to new_session_path
    assert_nil Session.find_by(id: session_record.id)
  end

  test "allows access while the session is still valid" do
    sign_in_as users(:admin)
    follow_redirect!

    assert_response :success
  end
end
