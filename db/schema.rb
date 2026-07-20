# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_07_20_214601) do
  create_table "passenger_manual_settlements", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "passenger_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["passenger_id"], name: "index_passenger_manual_settlements_on_passenger_id", unique: true
    t.index ["user_id"], name: "index_passenger_manual_settlements_on_user_id"
  end

  create_table "passenger_removals", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "passenger_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["passenger_id"], name: "index_passenger_removals_on_passenger_id", unique: true
    t.index ["user_id"], name: "index_passenger_removals_on_user_id"
  end

  create_table "passengers", force: :cascade do |t|
    t.string "cpf_normalized"
    t.datetime "created_at", null: false
    t.integer "expected_amount_override_minor"
    t.string "full_name", null: false
    t.string "parent_email"
    t.string "parent_name"
    t.string "parent_phone_number"
    t.integer "trip_id", null: false
    t.datetime "updated_at", null: false
    t.index ["trip_id", "cpf_normalized"], name: "index_passengers_on_trip_id_and_cpf_normalized", unique: true
    t.index ["trip_id"], name: "index_passengers_on_trip_id"
  end

  create_table "school_deactivations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "school_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["school_id"], name: "index_school_deactivations_on_school_id", unique: true
    t.index ["user_id"], name: "index_school_deactivations_on_user_id"
  end

  create_table "school_store_concealments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "school_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["school_id"], name: "index_school_store_concealments_on_school_id", unique: true
    t.index ["user_id"], name: "index_school_store_concealments_on_user_id"
  end

  create_table "schools", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.text "description"
    t.string "favicon_url"
    t.string "image_url"
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "url"
    t.string "wix_collection_id"
    t.index ["wix_collection_id"], name: "index_schools_on_wix_collection_id", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.datetime "expires_at", null: false
    t.string "ip_address"
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.integer "user_id", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "trip_deactivations", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "trip_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["trip_id"], name: "index_trip_deactivations_on_trip_id", unique: true
    t.index ["user_id"], name: "index_trip_deactivations_on_user_id"
  end

  create_table "trip_store_concealments", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "trip_id", null: false
    t.datetime "updated_at", null: false
    t.integer "user_id"
    t.index ["trip_id"], name: "index_trip_store_concealments_on_trip_id", unique: true
    t.index ["user_id"], name: "index_trip_store_concealments_on_user_id"
  end

  create_table "trips", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.integer "default_expected_amount_minor"
    t.text "description"
    t.datetime "expiration_date"
    t.string "image_url"
    t.integer "school_id", null: false
    t.string "title"
    t.datetime "updated_at", null: false
    t.string "wix_media_file_id"
    t.string "wix_product_id"
    t.string "wix_product_page_url"
    t.string "wix_product_slug"
    t.index ["school_id"], name: "index_trips_on_school_id"
    t.index ["wix_product_id"], name: "index_trips_on_wix_product_id", unique: true
  end

  create_table "users", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.integer "role", default: 0, null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "sessions", "users"
end
