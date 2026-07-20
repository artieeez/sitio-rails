require "test_helper"

class Schools::DeactivationsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
  end

  test "create deactivates the school" do
    school = schools(:active)
    post school_deactivation_url(school)

    assert_redirected_to schools_url
    assert school.reload.deactivated?
    assert school.store_concealed?
  end

  test "destroy activates the school" do
    school = schools(:inactive)
    delete school_deactivation_url(school)

    assert_redirected_to schools_url
    assert school.reload.active?
  end
end
