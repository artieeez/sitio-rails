require "rails_helper"

RSpec.describe "Pages", type: :request do
  it "redirects unauthenticated users from root to login (default-deny)" do
    get root_path
    expect(response).to redirect_to(new_session_path)
  end

  it "redirects unauthenticated users from about to login (default-deny)" do
    get about_path
    expect(response).to redirect_to(new_session_path)
  end
end
