require "test_helper"

class RegistrationsTest < ActionDispatch::IntegrationTest
  test "registers the first admin and starts a session when no users exist" do
    User.delete_all

    get new_registration_path
    assert_response :success

    assert_difference -> { User.count }, 1 do
      post registration_url, params: {
        email_address: "admin@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    end

    user = User.find_by!(email_address: "admin@example.com")
    assert user.admin?
    assert_redirected_to root_path

    follow_redirect!
    assert_response :success
  end

  test "redirects new to login when users already exist" do
    get new_registration_path
    assert_redirected_to new_session_path
  end

  test "redirects create to login without creating another user when users already exist" do
    assert_no_difference -> { User.count } do
      post registration_url, params: {
        email_address: "another@example.com",
        password: "password123",
        password_confirmation: "password123"
      }
    end

    assert_redirected_to new_session_path
  end
end
