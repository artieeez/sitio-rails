require "rails_helper"

RSpec.describe "Session expiry", type: :request do
  let(:password) { "password123" }
  let!(:user) do
    User.create!(
      email_address: "user@example.com",
      password: password,
      password_confirmation: password,
      role: :admin
    )
  end

  it "treats an expired session cookie as logged out" do
    post session_path, params: { email_address: user.email_address, password: password }
    expect(response).to redirect_to(root_path)

    session_record = Session.last!
    session_record.update_column(:expires_at, 1.minute.ago)

    get root_path

    expect(response).to redirect_to(new_session_path)
    expect(Session.find_by(id: session_record.id)).to be_nil
  end

  it "allows access while the session is still valid" do
    post session_path, params: { email_address: user.email_address, password: password }
    follow_redirect!

    expect(response).to have_http_status(:success)
  end
end
