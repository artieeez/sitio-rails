class CreateTrips < ActiveRecord::Migration[8.1]
  def change
    create_table :trips do |t|
      t.references :school, null: false, index: true
      t.string :title
      t.text :description
      t.string :image_url
      t.string :wix_product_id
      t.string :wix_product_slug
      t.string :wix_product_page_url
      t.string :wix_media_file_id
      t.integer :default_expected_amount_minor
      t.datetime :expiration_date

      t.timestamps
    end

    add_index :trips, :wix_product_id, unique: true

    create_table :trip_deactivations do |t|
      t.references :trip, null: false, index: { unique: true }
      t.references :user, index: true
      t.timestamps
    end

    create_table :trip_store_concealments do |t|
      t.references :trip, null: false, index: { unique: true }
      t.references :user, index: true
      t.timestamps
    end
  end
end
