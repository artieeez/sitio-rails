require "rails_helper"

RSpec.describe "Sessions", type: :request do
  before { Rails.cache.clear }

  let(:password) { "password123" }
  let!(:user) do
    User.create!(
      email_address: "user@example.com",
      password: password,
      password_confirmation: password,
      role: :admin
    )
  end

  describe "POST /session" do
    it "signs in with valid credentials" do
      post session_path, params: { email_address: user.email_address, password: password }

      expect(response).to redirect_to(root_path)
    end

    it "rejects invalid credentials" do
      post session_path, params: { email_address: user.email_address, password: "wrong" }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Try another email address or password.")
    end
  end

  describe "DELETE /session" do
    it "signs out" do
      post session_path, params: { email_address: user.email_address, password: password }
      delete session_path

      expect(response).to redirect_to(new_session_path)
      expect(response).to have_http_status(:see_other)
    end
  end

  describe "rate limiting on create" do
    it "redirects with try again later on the sixth failed attempt" do
      5.times do
        post session_path, params: { email_address: user.email_address, password: "wrong" }

        expect(response).to redirect_to(new_session_path)
        expect(flash[:alert]).to eq("Try another email address or password.")
      end

      post session_path, params: { email_address: user.email_address, password: "wrong" }

      expect(response).to redirect_to(new_session_path)
      expect(flash[:alert]).to eq("Try again later.")
    end
  end
end
