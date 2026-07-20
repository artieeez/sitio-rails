require "test_helper"

class HealthCheckTest < ActionDispatch::IntegrationTest
  test "returns 200 on GET /up without authentication" do
    get "/up"
    assert_response :ok
  end
end
