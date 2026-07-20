require "test_helper"

class Schools::DeletionsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
  end

  test "show renders deletion eligibility" do
    get school_deletion_url(schools(:active))
    assert_response :success
    assert_match "Excluir escola", response.body
  end

  test "destroy permanently deletes the school" do
    school = schools(:active)

    assert_difference -> { School.count }, -1 do
      delete school_deletion_url(school)
    end

    assert_redirected_to schools_url
  end
end
