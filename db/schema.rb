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

ActiveRecord::Schema[8.1].define(version: 2026_11_21_205636) do
  # These are extensions that must be enabled in order to support this database
  enable_extension "pg_catalog.plpgsql"

  create_table "action_text_rich_texts", force: :cascade do |t|
    t.string "name", null: false
    t.text "body"
    t.string "record_type", null: false
    t.bigint "record_id", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["record_type", "record_id", "name"], name: "index_action_text_rich_texts_uniqueness", unique: true
  end

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

  create_table "clicks", force: :cascade do |t|
    t.bigint "personal_link_id", null: false
    t.string "ip_address"
    t.text "user_agent"
    t.string "browser_name"
    t.string "browser_version"
    t.string "platform"
    t.string "device_type"
    t.text "referrer"
    t.string "accept_language"
    t.boolean "bot", default: false, null: false
    t.datetime "created_at", null: false
    t.index ["personal_link_id"], name: "index_clicks_on_personal_link_id"
  end

  create_table "groups", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "name", null: false
    t.text "description"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.string "email_subject"
    t.index ["user_id"], name: "index_groups_on_user_id"
  end

  create_table "links", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.string "title"
    t.string "url", null: false
    t.datetime "sent_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id"], name: "index_links_on_group_id"
  end

  create_table "members", force: :cascade do |t|
    t.bigint "group_id", null: false
    t.string "name", null: false
    t.string "email_address", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["group_id", "email_address"], name: "index_members_on_group_id_and_email_address", unique: true
    t.index ["group_id"], name: "index_members_on_group_id"
  end

  create_table "personal_links", force: :cascade do |t|
    t.bigint "link_id", null: false
    t.bigint "member_id", null: false
    t.string "token", null: false
    t.datetime "sent_at"
    t.integer "clicks_count", default: 0, null: false
    t.datetime "first_clicked_at"
    t.datetime "last_clicked_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["link_id", "member_id"], name: "index_personal_links_on_link_id_and_member_id", unique: true
    t.index ["link_id"], name: "index_personal_links_on_link_id"
    t.index ["member_id"], name: "index_personal_links_on_member_id"
    t.index ["token"], name: "index_personal_links_on_token", unique: true
  end

  create_table "sessions", force: :cascade do |t|
    t.bigint "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "active_storage_attachments", "active_storage_blobs", column: "blob_id"
  add_foreign_key "active_storage_variant_records", "active_storage_blobs", column: "blob_id"
  add_foreign_key "clicks", "personal_links"
  add_foreign_key "groups", "users"
  add_foreign_key "links", "groups"
  add_foreign_key "members", "groups"
  add_foreign_key "personal_links", "links"
  add_foreign_key "personal_links", "members"
  add_foreign_key "sessions", "users"
end
