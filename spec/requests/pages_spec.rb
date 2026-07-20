require "rails_helper"

RSpec.describe "Pages", type: :request do
  it "renders the root page with Tailwind markup and Stimulus hooks" do
    get root_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("text-emerald-800")
    expect(response.body).to include('data-controller="toggle"')
    expect(response.body).to include("Turbo Drive")
  end

  it "renders the about page for Turbo Drive navigation demos" do
    get about_path
    expect(response).to have_http_status(:ok)
    expect(response.body).to include("About")
  end
end
