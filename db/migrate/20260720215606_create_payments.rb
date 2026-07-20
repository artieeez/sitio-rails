class CreatePayments < ActiveRecord::Migration[8.1]
  def change
    create_table :payments do |t|
      t.references :passenger, null: false, index: true
      t.integer :amount_minor, null: false
      t.date :paid_on, null: false
      t.string :location, null: false
      t.string :payer_identity, null: false
      t.string :wix_transaction_id

      t.timestamps
    end

    add_index :payments, :wix_transaction_id, unique: true
  end
end
