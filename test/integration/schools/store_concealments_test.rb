require "test_helper"

class Schools::StoreConcealmentsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
  end

  test "create conceals the school in the store" do
    school = schools(:active)
    post school_store_concealment_url(school)

    assert_redirected_to school_url(school)
    assert school.reload.store_concealed?
  end

  test "destroy reveals an active school in the store" do
    school = schools(:concealed)
    delete school_store_concealment_url(school)

    assert_redirected_to school_url(school)
    assert school.reload.store_visible?
  end

  test "destroy rejects revealing an inactive school" do
    school = schools(:inactive)
    delete school_store_concealment_url(school)

    assert_redirected_to school_url(school)
    assert_equal "Cannot reveal an inactive school in the store", flash[:alert]
    assert school.reload.store_concealed?
  end
end
