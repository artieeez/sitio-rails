class CreateWixEvents < ActiveRecord::Migration[8.1]
  def change
    create_table :wix_events do |t|
      t.string :event_type, null: false
      t.string :wix_entity_id, null: false
      t.json :payload, null: false
      t.datetime :claimed_at
      t.datetime :processed_at
      t.datetime :failed_at
      t.text :last_error
      t.integer :attempts, default: 0, null: false

      t.timestamps
    end

    add_index :wix_events, :event_type
    add_index :wix_events, :wix_entity_id
    add_index :wix_events, :processed_at
  end
end
