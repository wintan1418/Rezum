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

ActiveRecord::Schema[7.2].define(version: 2026_03_04_141441) do
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

  create_table "ahoy_events", force: :cascade do |t|
    t.bigint "visit_id"
    t.bigint "user_id"
    t.string "name"
    t.jsonb "properties"
    t.datetime "time"
    t.index ["name", "time"], name: "index_ahoy_events_on_name_and_time"
    t.index ["properties"], name: "index_ahoy_events_on_properties", opclass: :jsonb_path_ops, using: :gin
    t.index ["user_id"], name: "index_ahoy_events_on_user_id"
    t.index ["visit_id"], name: "index_ahoy_events_on_visit_id"
  end

  create_table "ahoy_visits", force: :cascade do |t|
    t.string "visit_token"
    t.string "visitor_token"
    t.bigint "user_id"
    t.string "ip"
    t.text "user_agent"
    t.text "referrer"
    t.string "referring_domain"
    t.text "landing_page"
    t.string "browser"
    t.string "os"
    t.string "device_type"
    t.string "country"
    t.string "region"
    t.string "city"
    t.float "latitude"
    t.float "longitude"
    t.string "utm_source"
    t.string "utm_medium"
    t.string "utm_term"
    t.string "utm_content"
    t.string "utm_campaign"
    t.string "app_version"
    t.string "os_version"
    t.string "platform"
    t.datetime "started_at"
    t.index ["user_id"], name: "index_ahoy_visits_on_user_id"
    t.index ["visit_token"], name: "index_ahoy_visits_on_visit_token", unique: true
    t.index ["visitor_token", "started_at"], name: "index_ahoy_visits_on_visitor_token_and_started_at"
  end

  create_table "articles", force: :cascade do |t|
    t.string "title", null: false
    t.string "slug", null: false
    t.string "author"
    t.string "category"
    t.string "meta_description"
    t.string "meta_title"
    t.string "featured_image_url"
    t.text "content", null: false
    t.text "excerpt"
    t.boolean "published", default: false
    t.datetime "published_at"
    t.integer "reading_time", default: 5
    t.json "tags", default: []
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["category"], name: "index_articles_on_category"
    t.index ["published", "published_at"], name: "index_articles_on_published_and_published_at"
    t.index ["published"], name: "index_articles_on_published"
    t.index ["slug"], name: "index_articles_on_slug", unique: true
  end

  create_table "conversations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "subject"
    t.string "status", default: "open"
    t.datetime "last_message_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status"], name: "index_conversations_on_status"
    t.index ["user_id"], name: "index_conversations_on_user_id"
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
    t.index ["user_id", "status"], name: "index_cover_letters_on_user_id_and_status"
    t.index ["user_id"], name: "index_cover_letters_on_user_id"
  end

  create_table "hire_messages", force: :cascade do |t|
    t.string "name", null: false
    t.string "email", null: false
    t.text "message", null: false
    t.boolean "read", default: false, null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["created_at"], name: "index_hire_messages_on_created_at"
    t.index ["read"], name: "index_hire_messages_on_read"
  end

  create_table "interview_preps", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "resume_id"
    t.bigint "job_application_id"
    t.text "job_description"
    t.string "company_name"
    t.string "target_role"
    t.json "questions", default: []
    t.json "company_questions", default: []
    t.string "status", default: "pending"
    t.string "provider"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["job_application_id"], name: "index_interview_preps_on_job_application_id"
    t.index ["resume_id"], name: "index_interview_preps_on_resume_id"
    t.index ["user_id"], name: "index_interview_preps_on_user_id"
  end

  create_table "job_applications", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "resume_id"
    t.bigint "cover_letter_id"
    t.string "company_name", null: false
    t.string "role", null: false
    t.string "url"
    t.string "status", default: "applied"
    t.date "applied_at"
    t.date "follow_up_at"
    t.text "notes"
    t.string "salary_offered"
    t.string "location"
    t.boolean "remote", default: false
    t.string "contact_name"
    t.string "contact_email"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["cover_letter_id"], name: "index_job_applications_on_cover_letter_id"
    t.index ["resume_id"], name: "index_job_applications_on_resume_id"
    t.index ["user_id", "status"], name: "index_job_applications_on_user_id_and_status"
    t.index ["user_id"], name: "index_job_applications_on_user_id"
  end

  create_table "job_scraper_settings", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.json "target_roles", default: []
    t.json "target_locations", default: []
    t.json "keywords", default: []
    t.integer "min_salary"
    t.boolean "remote_only", default: false
    t.boolean "auto_apply", default: false
    t.string "scrape_frequency", default: "daily"
    t.datetime "last_scraped_at"
    t.boolean "enabled", default: true
    t.string "experience_level"
    t.integer "max_results_per_scrape", default: 20
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_job_scraper_settings_on_user_id", unique: true
  end

  create_table "linkedin_optimizations", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.bigint "resume_id"
    t.string "target_role"
    t.text "current_headline"
    t.text "optimized_headline"
    t.text "current_about"
    t.text "optimized_about"
    t.text "current_experience"
    t.text "optimized_experience"
    t.json "suggestions", default: []
    t.string "status", default: "draft"
    t.string "provider"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resume_id"], name: "index_linkedin_optimizations_on_resume_id"
    t.index ["user_id"], name: "index_linkedin_optimizations_on_user_id"
  end

  create_table "messages", force: :cascade do |t|
    t.bigint "conversation_id", null: false
    t.bigint "user_id", null: false
    t.text "body", null: false
    t.boolean "read", default: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["conversation_id", "read"], name: "index_messages_on_conversation_id_and_read"
    t.index ["conversation_id"], name: "index_messages_on_conversation_id"
    t.index ["user_id"], name: "index_messages_on_user_id"
  end

  create_table "payments", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "paystack_reference"
    t.integer "amount_cents"
    t.string "currency"
    t.string "status"
    t.string "description"
    t.integer "credits_purchased"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "client_secret"
    t.index ["user_id", "status"], name: "index_payments_on_user_id_and_status"
    t.index ["user_id"], name: "index_payments_on_user_id"
  end

  create_table "resume_sections", force: :cascade do |t|
    t.bigint "resume_id", null: false
    t.string "section_type", null: false
    t.json "content", default: {}
    t.integer "position", default: 0
    t.boolean "visible", default: true
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["resume_id", "position"], name: "index_resume_sections_on_resume_id_and_position"
    t.index ["resume_id"], name: "index_resume_sections_on_resume_id"
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
    t.string "template", default: "professional"
    t.datetime "expires_at"
    t.text "ats_analysis"
    t.index ["user_id", "status"], name: "index_resumes_on_user_id_and_status"
    t.index ["user_id"], name: "index_resumes_on_user_id"
  end

  create_table "scraped_jobs", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "company_name", null: false
    t.string "role", null: false
    t.string "location"
    t.string "salary_range"
    t.string "url"
    t.text "description"
    t.string "source", default: "google_jobs"
    t.string "job_type"
    t.boolean "remote", default: false
    t.integer "match_score", default: 0
    t.string "status", default: "new"
    t.datetime "applied_at"
    t.datetime "expires_at"
    t.json "tags", default: []
    t.text "notes"
    t.string "external_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["external_id"], name: "index_scraped_jobs_on_external_id"
    t.index ["user_id", "match_score"], name: "index_scraped_jobs_on_user_id_and_match_score"
    t.index ["user_id", "status"], name: "index_scraped_jobs_on_user_id_and_status"
    t.index ["user_id"], name: "index_scraped_jobs_on_user_id"
  end

  create_table "subscriptions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "paystack_subscription_code"
    t.string "status"
    t.string "plan_id"
    t.datetime "current_period_start"
    t.datetime "current_period_end"
    t.boolean "cancel_at_period_end"
    t.datetime "trial_start"
    t.datetime "trial_end"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["status", "user_id"], name: "index_subscriptions_on_status_and_user_id"
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
    t.integer "credits_remaining", default: 2
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
    t.string "paystack_customer_code"
    t.string "confirmation_token"
    t.datetime "confirmed_at"
    t.datetime "confirmation_sent_at"
    t.string "unconfirmed_email"
    t.integer "referral_credits_earned", default: 0
    t.boolean "referral_bonus_applied", default: false
    t.boolean "onboarding_completed", default: false
    t.integer "onboarding_step", default: 0
    t.datetime "last_email_sent_at"
    t.integer "email_sequence_stage", default: 0
    t.datetime "unsubscribed_at"
    t.boolean "admin", default: false
    t.datetime "disabled_at"
    t.boolean "scraping_in_progress", default: false
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
  add_foreign_key "conversations", "users"
  add_foreign_key "cover_letters", "resumes"
  add_foreign_key "cover_letters", "users"
  add_foreign_key "interview_preps", "job_applications"
  add_foreign_key "interview_preps", "resumes"
  add_foreign_key "interview_preps", "users"
  add_foreign_key "job_applications", "cover_letters"
  add_foreign_key "job_applications", "resumes"
  add_foreign_key "job_applications", "users"
  add_foreign_key "job_scraper_settings", "users"
  add_foreign_key "linkedin_optimizations", "resumes"
  add_foreign_key "linkedin_optimizations", "users"
  add_foreign_key "messages", "conversations"
  add_foreign_key "messages", "users"
  add_foreign_key "payments", "users"
  add_foreign_key "resume_sections", "resumes"
  add_foreign_key "resumes", "users"
  add_foreign_key "scraped_jobs", "users"
  add_foreign_key "subscriptions", "users"
end
