class AddExpiresAtToSessions < ActiveRecord::Migration[8.1]
  class Session < ApplicationRecord
    self.table_name = "sessions"
  end

  def up
    add_column :sessions, :expires_at, :datetime

    Session.reset_column_information
    Session.where(expires_at: nil).find_each do |session|
      session.update_columns(expires_at: session.created_at + 14.days)
    end

    change_column_null :sessions, :expires_at, false
  end

  def down
    remove_column :sessions, :expires_at
  end
end
