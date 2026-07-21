require "test_helper"

class Admin::WixEventsTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:admin) }

  test "index lists the wix event fixtures" do
    get admin_wix_events_url

    assert_response :success
    assert_match wix_events(:pending).wix_entity_id, response.body
    assert_match wix_events(:processed).wix_entity_id, response.body
    assert_match wix_events(:failed).wix_entity_id, response.body
  end

  test "show renders the payload" do
    get admin_wix_event_url(wix_events(:pending))

    assert_response :success
    assert_match "Fixture Collection", response.body
  end

  test "member is forbidden" do
    sign_out
    sign_in_as users(:member)

    get admin_wix_events_url

    assert_response :forbidden
  end
end
