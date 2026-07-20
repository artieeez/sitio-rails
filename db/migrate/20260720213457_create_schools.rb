class CreateSchools < ActiveRecord::Migration[8.1]
  def change
    create_table :schools do |t|
      t.string :title
      t.text :description
      t.string :url
      t.string :image_url
      t.string :favicon_url
      t.string :wix_collection_id

      t.timestamps
    end

    add_index :schools, :wix_collection_id, unique: true

    create_table :school_deactivations do |t|
      t.references :school, null: false, index: { unique: true }
      t.references :user, index: true
      t.timestamps
    end

    create_table :school_store_concealments do |t|
      t.references :school, null: false, index: { unique: true }
      t.references :user, index: true
      t.timestamps
    end
  end
end
