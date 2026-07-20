class CreatePassengers < ActiveRecord::Migration[8.1]
  def change
    create_table :passengers do |t|
      t.references :trip, null: false, index: true
      t.string :full_name, null: false
      t.string :cpf_normalized
      t.string :parent_name
      t.string :parent_phone_number
      t.string :parent_email
      t.integer :expected_amount_override_minor

      t.timestamps
    end

    add_index :passengers, [ :trip_id, :cpf_normalized ], unique: true, name: "index_passengers_on_trip_id_and_cpf_normalized"

    create_table :passenger_removals do |t|
      t.references :passenger, null: false, index: { unique: true }
      t.references :user, index: true
      t.timestamps
    end

    create_table :passenger_manual_settlements do |t|
      t.references :passenger, null: false, index: { unique: true }
      t.references :user, index: true
      t.timestamps
    end
  end
end
