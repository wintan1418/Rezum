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

ActiveRecord::Schema[7.2].define(version: 2025_09_10_202353) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "countries", primary_key: "code", id: { type: :string, limit: 2 }, force: :cascade do |t|
    t.string "name", null: false
    t.string "currency", limit: 3, default: "USD"
    t.string "timezone"
    t.json "supported_languages", default: ["en"]
    t.json "payment_methods", default: []
    t.decimal "vat_rate", precision: 5, scale: 4, default: "0.0"
    t.boolean "is_active", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["currency"], name: "index_countries_on_currency"
    t.index ["is_active"], name: "index_countries_on_is_active"
    t.index ["name"], name: "index_countries_on_name"
  end

  create_table "users", force: :cascade do |t|
    t.string "email", default: "", null: false
    t.string "encrypted_password", default: "", null: false
    t.string "reset_password_token"
    t.datetime "reset_password_sent_at"
    t.datetime "remember_created_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "first_name"
    t.string "last_name"
    t.string "phone"
    t.string "job_title"
    t.string "company"
    t.text "bio"
    t.string "country_code", limit: 2
    t.string "timezone"
    t.string "language", default: "en"
    t.string "currency", default: "USD"
    t.string "industry"
    t.integer "experience_level", default: 0
    t.string "linkedin_url"
    t.string "portfolio_url"
    t.integer "credits_remaining", default: 3
    t.integer "total_generations", default: 0
    t.integer "subscription_status", default: 0
    t.datetime "trial_ends_at"
    t.datetime "last_active_at"
    t.boolean "marketing_consent", default: false
    t.json "privacy_settings", default: {}
    t.json "notification_preferences", default: {}
    t.string "referral_code"
    t.bigint "referred_by_id"
    t.string "provider"
    t.string "uid"
    t.index ["country_code"], name: "index_users_on_country_code"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_active_at"], name: "index_users_on_last_active_at"
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid"
    t.index ["referral_code"], name: "index_users_on_referral_code", unique: true
    t.index ["referred_by_id"], name: "index_users_on_referred_by_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["subscription_status"], name: "index_users_on_subscription_status"
  end
end
