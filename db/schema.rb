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

ActiveRecord::Schema[7.2].define(version: 2025_09_12_232623) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.string "name", null: false
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.string "key", null: false
    t.string "filename", null: false
    t.string "content_type"
    t.text "metadata"
    t.string "service_name", null: false
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.datetime "created_at", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

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

  create_table "cover_letters", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "resume_id", null: false
    t.string "company_name"
    t.string "hiring_manager_name"
    t.string "target_role"
    t.string "tone"
    t.string "length"
    t.text "content"
    t.text "job_description"
    t.string "status"
    t.string "provider"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resume_id"], name: "index_cover_letters_on_resume_id"
    t.index ["user_id"], name: "index_cover_letters_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "stripe_payment_intent_id"
    t.integer "amount_cents"
    t.string "currency"
    t.string "status"
    t.string "description"
    t.integer "credits_purchased"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "client_secret"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "resumes", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.text "original_content"
    t.text "optimized_content"
    t.text "job_description"
    t.string "target_role"
    t.string "industry"
    t.string "experience_level"
    t.integer "ats_score"
    t.text "keywords"
    t.string "status"
    t.string "provider"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_resumes_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "stripe_subscription_id"
    t.string "status"
    t.string "plan_id"
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.boolean "cancel_at_period_end"
    t.datetime "trial_start"
    t.datetime "trial_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_subscriptions_on_user_id"
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
    t.string "stripe_customer_id"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.index ["confirmation_token"], name: "index_users_on_confirmation_token"
    t.index ["country_code"], name: "index_users_on_country_code"
    t.index ["email"], name: "index_users_on_email", unique: true
    t.index ["last_active_at"], name: "index_users_on_last_active_at"
    t.index ["provider", "uid"], name: "index_users_on_provider_and_uid"
    t.index ["referral_code"], name: "index_users_on_referral_code", unique: true
    t.index ["referred_by_id"], name: "index_users_on_referred_by_id"
    t.index ["reset_password_token"], name: "index_users_on_reset_password_token", unique: true
    t.index ["subscription_status"], name: "index_users_on_subscription_status"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "cover_letters", "resumes"
  add_foreign_key "cover_letters", "users"
  add_foreign_key "payments", "users"
  add_foreign_key "resumes", "users"
  add_foreign_key "subscriptions", "users"
end
