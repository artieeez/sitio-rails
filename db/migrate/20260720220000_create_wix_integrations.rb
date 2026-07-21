class CreateWixIntegrations < ActiveRecord::Migration[8.1]
  def change
    create_table :wix_integrations do |t|
      t.string :site_id
      t.text :public_key
      t.text :private_api_key

      t.timestamps
    end
  end
end
