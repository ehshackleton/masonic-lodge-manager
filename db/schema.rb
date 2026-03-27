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

ActiveRecord::Schema[8.1].define(version: 2026_03_26_000000) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

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

  create_table "brothers", force: :cascade do |t|
    t.boolean "active", default: true, null: false
    t.date "birth_date"
    t.datetime "created_at", null: false
    t.bigint "current_degree_id"
    t.string "email"
    t.string "first_name"
    t.string "last_name"
    t.bigint "lodge_id", null: false
    t.string "membership_status"
    t.string "mobile_phone"
    t.string "national_id"
    t.text "notes_private"
    t.string "phone"
    t.string "registry_number"
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

  add_foreign_key "audit_logs", "users"
  add_foreign_key "brothers", "degrees", column: "current_degree_id"
  add_foreign_key "brothers", "lodges"
  add_foreign_key "charges", "brothers"
  add_foreign_key "contact_messages", "users", column: "handled_by_user_id"
  add_foreign_key "correspondences", "lodges"
  add_foreign_key "correspondences", "users", column: "created_by_user_id"
  add_foreign_key "masonic_works", "brothers"
  add_foreign_key "masonic_works", "degrees"
  add_foreign_key "masonic_works", "lodges"
  add_foreign_key "masonic_works", "users", column: "reviewer_user_id"
  add_foreign_key "minutes", "users", column: "created_by_user_id"
  add_foreign_key "payments", "brothers"
  add_foreign_key "payments", "users", column: "received_by_user_id"
  add_foreign_key "user_roles", "roles"
  add_foreign_key "user_roles", "users"
end
