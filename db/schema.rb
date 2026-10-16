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

ActiveRecord::Schema[8.1].define(version: 2026_10_16_074815) do
  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
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
    t.string "role", default: "user", null: false
    t.string "locale"
    t.string "date_format"
    t.integer "first_weekday"
    t.string "time_format"
    t.string "time_zone"
    t.string "theme"
    t.string "detected_time_zone"
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "date_format IN ('dmy', 'mdy', 'ymd')", name: "chk_users_date_format"
    t.check_constraint "email_address = lower(trim(email_address))", name: "chk_users_email_normalized"
    t.check_constraint "first_weekday BETWEEN 0 AND 6", name: "chk_users_first_weekday"
    t.check_constraint "locale GLOB '[a-z][a-z]'", name: "chk_users_locale_shape"
    t.check_constraint "role IN ('admin', 'user')", name: "chk_users_role"
    t.check_constraint "theme IN ('light', 'dark')", name: "chk_users_theme"
    t.check_constraint "time_format IN ('12h', '24h')", name: "chk_users_time_format"
  end

  add_foreign_key "sessions", "users", on_delete: :cascade
end
