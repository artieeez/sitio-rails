require "test_helper"

class SqliteJournalModeTest < ActiveSupport::TestCase
  test "uses delete (rollback) journal mode, not WAL (ADR-003)" do
    mode = ActiveRecord::Base.connection.select_value("PRAGMA journal_mode;")
    assert_equal "delete", mode.to_s.downcase
  end
end
