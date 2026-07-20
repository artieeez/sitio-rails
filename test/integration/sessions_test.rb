require "test_helper"

class SessionsTest < ActionDispatch::IntegrationTest
  setup { Rails.cache.clear }

  test "signs in with valid credentials" do
    sign_in_as users(:admin)
    assert_redirected_to root_path
  end

  test "rejects invalid credentials" do
    post session_url, params: { email_address: users(:admin).email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_equal "Try another email address or password.", flash[:alert]
  end

  test "signs out" do
    sign_in_as users(:admin)
    delete session_url

    assert_redirected_to new_session_path
    assert_response :see_other
  end

  test "redirects with try again later on the sixth failed attempt" do
    5.times do
      post session_url, params: { email_address: users(:admin).email_address, password: "wrong" }

      assert_redirected_to new_session_path
      assert_equal "Try another email address or password.", flash[:alert]
    end

    post session_url, params: { email_address: users(:admin).email_address, password: "wrong" }

    assert_redirected_to new_session_path
    assert_equal "Try again later.", flash[:alert]
  end
end
