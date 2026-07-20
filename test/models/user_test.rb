require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "is valid with email, password, and defaults role to member" do
    user = User.new(email_address: "new@example.com", password: "password123", password_confirmation: "password123")
    assert user.valid?
    assert_equal "member", user.role
  end

  test "defaults role to member on create" do
    user = User.create!(email_address: "default@example.com", password: "password123", password_confirmation: "password123")
    assert user.member?
    assert_not user.admin?
  end

  test "reports admin? and member? from the role enum" do
    assert users(:admin).admin?
    assert_not users(:admin).member?
    assert users(:member).member?
    assert_not users(:member).admin?
  end

  test "rejects an invalid role value at the model level" do
    user = User.new(email_address: "bad@example.com", password: "password123", password_confirmation: "password123")
    assert_raises(ArgumentError) { user.role = :superuser }
  end

  test "authenticate_by authenticates with valid credentials" do
    user = User.authenticate_by(email_address: users(:admin).email_address, password: "password")
    assert user.present?
    assert_equal users(:admin), user
  end

  test "authenticate_by returns nil for invalid credentials" do
    assert_nil User.authenticate_by(email_address: users(:admin).email_address, password: "wrong")
  end
end
