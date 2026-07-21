class CreateAuditLogs < ActiveRecord::Migration[8.1]
  def change
    create_table :audit_logs do |t|
      t.string :user_id, null: false
      t.string :user_email
      t.string :user_name
      t.string :action, null: false
      t.string :resource, null: false
      t.string :ip_address

      t.datetime :created_at, null: false
    end

    add_index :audit_logs, :created_at
    add_index :audit_logs, :user_id
  end
end
