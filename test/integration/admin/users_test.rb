require "test_helper"

class Admin::UsersTest < ActionDispatch::IntegrationTest
  setup { Rails.cache.clear }

  test "admin creates member" do
    sign_in_as users(:admin)

    assert_difference -> { User.count }, 1 do
      post admin_users_url, params: {
        user: {
          email_address: "new-member@example.com",
          password: "password123",
          password_confirmation: "password123",
          role: "member"
        }
      }
    end

    assert User.find_by!(email_address: "new-member@example.com").member?
  end

  test "admin creates admin" do
    sign_in_as users(:admin)

    assert_difference -> { User.count }, 1 do
      post admin_users_url, params: {
        user: {
          email_address: "other-admin@example.com",
          password: "password123",
          password_confirmation: "password123",
          role: "admin"
        }
      }
    end

    assert User.find_by!(email_address: "other-admin@example.com").admin?
  end

  test "member denied (403)" do
    sign_in_as users(:member)

    get admin_users_url

    assert_response :forbidden
  end

  test "new member can log in after being created" do
    sign_in_as users(:admin)

    post admin_users_url, params: {
      user: {
        email_address: "newmember@example.com",
        password: "password123",
        password_confirmation: "password123",
        role: "member"
      }
    }

    sign_out

    post session_url, params: { email_address: "newmember@example.com", password: "password123" }

    assert_redirected_to root_path
  end
end
