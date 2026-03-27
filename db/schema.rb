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

ActiveRecord::Schema[8.1].define(version: 2026_03_27_110000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "active_storage_attachments", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.datetime "created_at", null: false
    t.string "name", null: false
    t.bigint "record_id", null: false
    t.string "record_type", null: false
    t.index ["blob_id"], name: "index_active_storage_attachments_on_blob_id"
    t.index ["record_type", "record_id", "name", "blob_id"], name: "index_active_storage_attachments_uniqueness", unique: true
  end

  create_table "active_storage_blobs", force: :cascade do |t|
    t.bigint "byte_size", null: false
    t.string "checksum"
    t.string "content_type"
    t.datetime "created_at", null: false
    t.string "filename", null: false
    t.string "key", null: false
    t.text "metadata"
    t.string "service_name", null: false
    t.index ["key"], name: "index_active_storage_blobs_on_key", unique: true
  end

  create_table "active_storage_variant_records", force: :cascade do |t|
    t.bigint "blob_id", null: false
    t.string "variation_digest", null: false
    t.index ["blob_id", "variation_digest"], name: "index_active_storage_variant_records_uniqueness", unique: true
  end

  create_table "audit_logs", force: :cascade do |t|
    t.string "action", null: false
    t.bigint "auditable_id", null: false
    t.string "auditable_type", null: false
    t.datetime "created_at", null: false
    t.string "ip_address"
    t.jsonb "metadata", default: {}
    t.datetime "updated_at", null: false
    t.string "user_agent"
    t.bigint "user_id"
    t.index ["auditable_type", "auditable_id"], name: "index_audit_logs_on_auditable_type_and_auditable_id"
    t.index ["user_id"], name: "index_audit_logs_on_user_id"
  end

  create_table "brother_degree_histories", force: :cascade do |t|
    t.bigint "brother_id", null: false
    t.date "ceremony_date"
    t.datetime "created_at", null: false
    t.bigint "degree_id", null: false
    t.text "notes"
    t.datetime "updated_at", null: false
    t.index ["brother_id", "degree_id", "ceremony_date"], name: "idx_brother_degree_history_search"
    t.index ["brother_id"], name: "index_brother_degree_histories_on_brother_id"
    t.index ["degree_id"], name: "index_brother_degree_histories_on_degree_id"
  end

  create_table "brother_office_assignments", force: :cascade do |t|
    t.bigint "brother_id", null: false
    t.datetime "created_at", null: false
    t.date "end_date"
    t.text "notes"
    t.bigint "office_id", null: false
    t.date "start_date"
    t.datetime "updated_at", null: false
    t.index ["brother_id", "office_id", "start_date"], name: "idx_brother_office_assignment_search"
    t.index ["brother_id"], name: "index_brother_office_assignments_on_brother_id"
    t.index ["office_id"], name: "index_brother_office_assignments_on_office_id"
  end

  create_table "brothers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "address"
    t.date "birth_date"
    t.string "city"
    t.datetime "created_at", null: false
    t.bigint "current_degree_id"
    t.datetime "deceased_at"
    t.string "email"
    t.string "emergency_contact_name"
    t.string "emergency_contact_phone"
    t.string "employer"
    t.date "exaltation_date"
    t.string "father_name"
    t.string "first_name"
    t.date "initiation_date"
    t.string "last_name"
    t.bigint "lodge_id", null: false
    t.string "marital_status"
    t.string "membership_status"
    t.string "mobile_phone"
    t.string "mother_name"
    t.string "national_id"
    t.text "notes_private"
    t.string "phone"
    t.string "profession"
    t.date "raising_date"
    t.string "registry_number"
    t.string "spouse_name"
    t.date "status_since"
    t.string "symbolic_name"
    t.datetime "updated_at", null: false
    t.index ["current_degree_id"], name: "index_brothers_on_current_degree_id"
    t.index ["lodge_id"], name: "index_brothers_on_lodge_id"
    t.index ["membership_status"], name: "index_brothers_on_membership_status"
    t.index ["registry_number"], name: "index_brothers_on_registry_number"
    t.index ["symbolic_name"], name: "index_brothers_on_symbolic_name"
  end

  create_table "charges", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.bigint "brother_id", null: false
    t.datetime "created_at", null: false
    t.date "due_on"
    t.text "notes"
    t.integer "period_month", null: false
    t.integer "period_year", null: false
    t.string "status", default: "pending", null: false
    t.datetime "updated_at", null: false
    t.index ["brother_id", "status", "due_on"], name: "index_charges_on_brother_id_and_status_and_due_on"
    t.index ["brother_id"], name: "index_charges_on_brother_id"
  end

  create_table "contact_messages", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.bigint "handled_by_user_id"
    t.text "message", null: false
    t.string "name", null: false
    t.string "phone"
    t.string "status", default: "new", null: false
    t.string "subject"
    t.datetime "updated_at", null: false
  end

  create_table "correspondences", force: :cascade do |t|
    t.text "body"
    t.string "confidentiality_level", default: "internal"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id"
    t.string "direction", null: false
    t.string "document_type"
    t.string "folio"
    t.bigint "lodge_id", null: false
    t.date "received_on"
    t.string "recipient_name"
    t.string "sender_name"
    t.date "sent_on"
    t.string "status", default: "draft"
    t.string "subject", null: false
    t.text "summary"
    t.datetime "updated_at", null: false
    t.index ["folio"], name: "index_correspondences_on_folio"
    t.index ["lodge_id"], name: "index_correspondences_on_lodge_id"
  end

  create_table "degrees", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "key", null: false
    t.string "name", null: false
    t.integer "rank_order", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_degrees_on_key", unique: true
  end

  create_table "ledger_entries", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.string "concept", null: false
    t.datetime "created_at", null: false
    t.string "credit_account", null: false
    t.string "debit_account", null: false
    t.bigint "lodge_id", null: false
    t.text "notes"
    t.date "occurred_on", null: false
    t.integer "period_month", null: false
    t.integer "period_year", null: false
    t.bigint "reference_id", null: false
    t.string "reference_type", null: false
    t.datetime "updated_at", null: false
    t.index ["lodge_id", "period_year", "period_month"], name: "idx_ledger_entries_period"
    t.index ["lodge_id"], name: "index_ledger_entries_on_lodge_id"
    t.index ["reference_type", "reference_id"], name: "idx_ledger_entries_reference"
  end

  create_table "lodges", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.string "address"
    t.datetime "created_at", null: false
    t.text "description"
    t.string "jurisdiction"
    t.string "name", null: false
    t.string "number"
    t.string "orient"
    t.string "public_email"
    t.string "public_phone"
    t.string "rite"
    t.datetime "updated_at", null: false
  end

  create_table "masonic_works", force: :cascade do |t|
    t.text "abstract"
    t.date "assigned_on"
    t.text "body"
    t.bigint "brother_id", null: false
    t.datetime "created_at", null: false
    t.bigint "degree_id"
    t.date "due_on"
    t.bigint "lodge_id", null: false
    t.date "presented_on"
    t.text "private_notes"
    t.bigint "reviewer_user_id"
    t.string "status", default: "assigned", null: false
    t.string "title", null: false
    t.string "topic"
    t.datetime "updated_at", null: false
    t.index ["brother_id", "status"], name: "index_masonic_works_on_brother_id_and_status"
    t.index ["brother_id"], name: "index_masonic_works_on_brother_id"
    t.index ["degree_id"], name: "index_masonic_works_on_degree_id"
    t.index ["lodge_id"], name: "index_masonic_works_on_lodge_id"
  end

  create_table "minutes", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.bigint "created_by_user_id"
    t.string "folio"
    t.date "session_date"
    t.string "status", default: "draft"
    t.text "summary"
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.string "visibility", default: "internal"
    t.index ["session_date"], name: "index_minutes_on_session_date"
  end

  create_table "monthly_closures", force: :cascade do |t|
    t.datetime "closed_at", null: false
    t.bigint "closed_by_user_id"
    t.datetime "created_at", null: false
    t.bigint "lodge_id", null: false
    t.text "notes"
    t.integer "period_month", null: false
    t.integer "period_year", null: false
    t.datetime "updated_at", null: false
    t.index ["closed_by_user_id"], name: "index_monthly_closures_on_closed_by_user_id"
    t.index ["lodge_id", "period_year", "period_month"], name: "idx_monthly_closures_period", unique: true
    t.index ["lodge_id"], name: "index_monthly_closures_on_lodge_id"
  end

  create_table "offices", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_offices_on_key", unique: true
  end

  create_table "payment_allocations", force: :cascade do |t|
    t.decimal "applied_amount", precision: 12, scale: 2, null: false
    t.bigint "charge_id", null: false
    t.datetime "created_at", null: false
    t.bigint "payment_id", null: false
    t.datetime "updated_at", null: false
    t.index ["charge_id"], name: "index_payment_allocations_on_charge_id"
    t.index ["payment_id", "charge_id"], name: "index_payment_allocations_on_payment_id_and_charge_id", unique: true
    t.index ["payment_id"], name: "index_payment_allocations_on_payment_id"
  end

  create_table "payments", force: :cascade do |t|
    t.decimal "amount", precision: 12, scale: 2, null: false
    t.bigint "brother_id", null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "CLP", null: false
    t.text "notes"
    t.date "paid_on", null: false
    t.string "payment_method"
    t.bigint "received_by_user_id"
    t.string "reference"
    t.datetime "updated_at", null: false
    t.index ["brother_id", "paid_on"], name: "index_payments_on_brother_id_and_paid_on"
    t.index ["brother_id"], name: "index_payments_on_brother_id"
  end

  create_table "public_pages", force: :cascade do |t|
    t.text "body"
    t.datetime "created_at", null: false
    t.boolean "published", default: false, null: false
    t.datetime "published_at"
    t.string "seo_description"
    t.string "seo_title"
    t.string "slug", null: false
    t.string "title", null: false
    t.datetime "updated_at", null: false
    t.index ["slug"], name: "index_public_pages_on_slug", unique: true
  end

  create_table "roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.string "description"
    t.string "key", null: false
    t.string "name", null: false
    t.datetime "updated_at", null: false
    t.index ["key"], name: "index_roles_on_key", unique: true
  end

  create_table "treasury_settings", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "currency", default: "CLP", null: false
    t.integer "due_day", default: 10, null: false
    t.bigint "lodge_id", null: false
    t.decimal "monthly_fee", precision: 12, scale: 2, default: "0.0", null: false
    t.datetime "updated_at", null: false
    t.index ["lodge_id"], name: "index_treasury_settings_on_lodge_id"
  end

  create_table "user_roles", force: :cascade do |t|
    t.datetime "created_at", null: false
    t.bigint "role_id", null: false
    t.datetime "updated_at", null: false
    t.bigint "user_id", null: false
    t.index ["role_id"], name: "index_user_roles_on_role_id"
    t.index ["user_id", "role_id"], name: "index_user_roles_on_user_id_and_role_id", unique: true
    t.index ["user_id"], name: "index_user_roles_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.datetime "created_at", null: false
    t.string "email", null: false
    t.integer "failed_attempts", default: 0, null: false
    t.datetime "last_sign_in_at"
    t.string "locale", default: "es"
    t.datetime "locked_at"
    t.string "password_digest"
    t.string "time_zone", default: "America/Santiago"
    t.datetime "updated_at", null: false
    t.index ["email"], name: "index_users_on_email", unique: true
  end

  create_table "work_reviews", force: :cascade do |t|
    t.text "comments"
    t.datetime "created_at", null: false
    t.bigint "masonic_work_id", null: false
    t.date "reviewed_on", null: false
    t.bigint "reviewer_user_id", null: false
    t.string "status", default: "commented", null: false
    t.datetime "updated_at", null: false
    t.index ["masonic_work_id"], name: "index_work_reviews_on_masonic_work_id"
    t.index ["reviewer_user_id"], name: "index_work_reviews_on_reviewer_user_id"
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "audit_logs", "users"
  add_foreign_key "brother_degree_histories", "brothers"
  add_foreign_key "brother_degree_histories", "degrees"
  add_foreign_key "brother_office_assignments", "brothers"
  add_foreign_key "brother_office_assignments", "offices"
  add_foreign_key "brothers", "degrees", column: "current_degree_id"
  add_foreign_key "brothers", "lodges"
  add_foreign_key "charges", "brothers"
  add_foreign_key "contact_messages", "users", column: "handled_by_user_id"
  add_foreign_key "correspondences", "lodges"
  add_foreign_key "correspondences", "users", column: "created_by_user_id"
  add_foreign_key "ledger_entries", "lodges"
  add_foreign_key "masonic_works", "brothers"
  add_foreign_key "masonic_works", "degrees"
  add_foreign_key "masonic_works", "lodges"
  add_foreign_key "masonic_works", "users", column: "reviewer_user_id"
  add_foreign_key "minutes", "users", column: "created_by_user_id"
  add_foreign_key "monthly_closures", "lodges"
  add_foreign_key "monthly_closures", "users", column: "closed_by_user_id"
  add_foreign_key "payment_allocations", "charges"
  add_foreign_key "payment_allocations", "payments"
  add_foreign_key "payments", "brothers"
  add_foreign_key "payments", "users", column: "received_by_user_id"
  add_foreign_key "treasury_settings", "lodges"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
  add_foreign_key "work_reviews", "masonic_works"
  add_foreign_key "work_reviews", "users", column: "reviewer_user_id"
end
