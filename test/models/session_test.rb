require "test_helper"

class SessionTest < ActiveSupport::TestCase
  test "expires_at is set to about 14 days from now on create" do
    session = users(:admin).sessions.create!(user_agent: "Minitest", ip_address: "127.0.0.1")

    assert_in_delta 14.days.from_now, session.expires_at, 2.seconds
  end
end
