require "rails_helper"

RSpec.describe "Dashboard", type: :request do
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

  let!(:member) do
    User.create!(
      email_address: "member@example.com",
      password: password,
      password_confirmation: password,
      role: :member
    )
  end

  def sign_in_as(user)
    post session_path, params: { email_address: user.email_address, password: password }
  end

  it "redirects unauthenticated users from root to login (default-deny)" do
    get root_path

    expect(response).to redirect_to(new_session_path)
  end

  it "member can see dashboard but not admin demo" do
    sign_in_as(member)

    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Dashboard")

    get dashboard_admin_demo_path
    expect(response).to have_http_status(:forbidden)
  end

  it "admin can see admin demo" do
    sign_in_as(admin)

    get dashboard_admin_demo_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Admin-only content")
  end
end
