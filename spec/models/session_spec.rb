require "rails_helper"

RSpec.describe Session, type: :model do
  let(:user) do
    User.create!(
      email_address: "user@example.com",
      password: "password123",
      password_confirmation: "password123",
      role: :admin
    )
  end

  describe "expires_at" do
    it "is set to about 14 days from now on create" do
      session = user.sessions.create!(user_agent: "RSpec", ip_address: "127.0.0.1")

      expect(session.expires_at).to be_within(2.seconds).of(14.days.from_now)
    end
  end
end
