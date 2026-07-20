require "rails_helper"

RSpec.describe "Admin::Users", type: :request do
  before { Rails.cache.clear }

  let(:password) { "password123" }

  let!(:admin) do
    User.create!(
      email_address: "admin@example.com",
      password: password,
      password_confirmation: password,
      role: :admin
    )
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: password }
  end

  describe "POST /admin/users" do
    before { sign_in_as(admin) }

    it "admin creates member" do
      expect {
        post admin_users_path, params: {
          user: {
            email_address: "member@example.com",
            password: password,
            password_confirmation: password,
            role: "member"
          }
        }
      }.to change(User, :count).by(1)

      expect(User.find_by!(email_address: "member@example.com")).to be_member
    end

    it "admin creates admin" do
      expect {
        post admin_users_path, params: {
          user: {
            email_address: "other-admin@example.com",
            password: password,
            password_confirmation: password,
            role: "admin"
          }
        }
      }.to change(User, :count).by(1)

      expect(User.find_by!(email_address: "other-admin@example.com")).to be_admin
    end
  end

  describe "GET /admin/users" do
    let!(:member) do
      User.create!(
        email_address: "member@example.com",
        password: password,
        password_confirmation: password,
        role: :member
      )
    end

    it "member denied (403)" do
      sign_in_as(member)

      get admin_users_path

      expect(response).to have_http_status(:forbidden)
    end
  end

  it "new member can log in after being created" do
    sign_in_as(admin)

    post admin_users_path, params: {
      user: {
        email_address: "newmember@example.com",
        password: password,
        password_confirmation: password,
        role: "member"
      }
    }

    delete session_path

    post session_path, params: { email_address: "newmember@example.com", password: password }

    expect(response).to redirect_to(root_path)
  end
end
