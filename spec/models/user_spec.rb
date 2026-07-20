require "rails_helper"

RSpec.describe User, type: :model do
  describe "validations and defaults" do
    it "is valid with email, password, and default member role" do
      user = User.new(email_address: "member@example.com", password: "password123", password_confirmation: "password123")
      expect(user).to be_valid
      expect(user.role).to eq("member")
    end

    it "defaults role to member" do
      user = User.create!(email_address: "default@example.com", password: "password123", password_confirmation: "password123")
      expect(user).to be_member
      expect(user).not_to be_admin
    end
  end

  describe "role predicates" do
    it "reports admin? and member? from the role enum" do
      admin = User.create!(email_address: "admin@example.com", password: "password123", password_confirmation: "password123", role: :admin)
      member = User.create!(email_address: "member2@example.com", password: "password123", password_confirmation: "password123", role: :member)

      expect(admin).to be_admin
      expect(admin).not_to be_member
      expect(member).to be_member
      expect(member).not_to be_admin
    end

    it "rejects an invalid role value at the model level" do
      user = User.new(email_address: "bad@example.com", password: "password123", password_confirmation: "password123")
      expect { user.role = :superuser }.to raise_error(ArgumentError)
    end
  end

  describe ".authenticate_by" do
    it "authenticates with valid credentials" do
      User.create!(email_address: "login@example.com", password: "password123", password_confirmation: "password123")
      user = User.authenticate_by(email_address: "login@example.com", password: "password123")
      expect(user).to be_present
      expect(user.email_address).to eq("login@example.com")
    end

    it "returns nil for invalid credentials" do
      User.create!(email_address: "login2@example.com", password: "password123", password_confirmation: "password123")
      expect(User.authenticate_by(email_address: "login2@example.com", password: "wrong")).to be_nil
    end
  end
end
