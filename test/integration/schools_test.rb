require "test_helper"

class SchoolsTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:admin)
  end

  test "index lists active schools and can include inactive" do
    get schools_url
    assert_response :success
    assert_match schools(:active).title, response.body
    assert_no_match schools(:inactive).title, response.body

    get schools_url(include_inactive: true)
    assert_response :success
    assert_match schools(:inactive).title, response.body
  end

  test "creates a school" do
    assert_difference -> { School.count }, 1 do
      post schools_url, params: {
        school: {
          title: "Nova Escola",
          description: "Descrição",
          url: "https://example.com/nova"
        }
      }
    end

    school = School.order(:id).last
    assert_redirected_to school_url(school)
    assert_equal "Nova Escola", school.title
  end

  test "redisplays the form when create is invalid" do
    post schools_url, params: { school: { url: "bad" } }

    assert_response :unprocessable_entity
  end

  test "updates a school" do
    school = schools(:active)
    patch school_url(school), params: { school: { title: "Título Atualizado" } }

    assert_redirected_to school_url(school)
    assert_equal "Título Atualizado", school.reload.title
  end

  test "requires authentication" do
    sign_out
    get schools_url
    assert_redirected_to new_session_path
  end
end
