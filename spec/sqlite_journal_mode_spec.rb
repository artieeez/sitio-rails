require "rails_helper"

RSpec.describe "SQLite journal mode" do
  it "uses delete (rollback) journal mode, not WAL (ADR-003)" do
    mode = ActiveRecord::Base.connection.select_value("PRAGMA journal_mode;")
    expect(mode.to_s.downcase).to eq("delete")
  end
end
