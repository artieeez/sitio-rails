require "rails_helper"

RSpec.describe "Registrations", type: :request do
  describe "when no users exist" do
    it "registers the first admin and starts a session" do
      get new_registration_path
      expect(response).to have_http_status(:success)

      expect {
        post registration_path, params: {
          email_address: "admin@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }.to change(User, :count).by(1)

      user = User.find_by!(email_address: "admin@example.com")
      expect(user).to be_admin
      expect(response).to redirect_to(root_path)

      follow_redirect!
      expect(response).to have_http_status(:success)
    end
  end

  describe "when users already exist" do
    before do
      User.create!(email_address: "existing@example.com", password: "password123", password_confirmation: "password123", role: :admin)
    end

    it "redirects new to login" do
      get new_registration_path
      expect(response).to redirect_to(new_session_path)
    end

    it "redirects create to login without creating another user" do
      expect {
        post registration_path, params: {
          email_address: "another@example.com",
          password: "password123",
          password_confirmation: "password123"
        }
      }.not_to change(User, :count)

      expect(response).to redirect_to(new_session_path)
    end
  end
end
