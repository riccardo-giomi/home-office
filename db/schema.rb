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

ActiveRecord::Schema[8.1].define(version: 2026_10_25_110000) do
  create_table "core_entities", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "record_type", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "deleted_at"
    t.index ["deleted_at"], name: "index_core_entities_purge", where: "deleted_at IS NOT NULL"
    t.index ["id", "record_type"], name: "index_core_entities_on_id_and_record_type", unique: true
    t.index ["id", "user_id", "record_type"], name: "index_core_entities_on_id_and_user_id_and_record_type", unique: true
    t.index ["id", "user_id"], name: "index_core_entities_on_id_and_user_id", unique: true
    t.index ["user_id", "deleted_at"], name: "index_core_entities_trash", where: "deleted_at IS NOT NULL"
  end

  create_table "planner_items", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "record_type", default: "Planner::Item", null: false
    t.string "type", null: false
    t.string "title", null: false
    t.text "notes"
    t.date "day"
    t.datetime "starts_at"
    t.datetime "ends_at"
    t.string "time_zone"
    t.string "state", default: "active", null: false
    t.integer "tracks_done", default: 0, null: false
    t.datetime "done_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "priority", default: 1, null: false
    t.integer "position", null: false
    t.index ["user_id", "type", "day", "starts_at"], name: "index_planner_items_on_day"
    t.index ["user_id", "type", "position"], name: "index_planner_items_position", unique: true
    t.check_constraint "(starts_at IS NULL) = (ends_at IS NULL) AND (starts_at IS NULL) = (time_zone IS NULL)", name: "chk_planner_items_times_paired"
    t.check_constraint "day IS NOT NULL OR type = 'Planner::Todo'", name: "chk_planner_items_day_required"
    t.check_constraint "day IS NULL OR day = date(day)", name: "chk_planner_items_day_format"
    t.check_constraint "done_at IS NULL OR tracks_done = 1", name: "chk_planner_items_done_tracked"
    t.check_constraint "ends_at > starts_at", name: "chk_planner_items_window_order"
    t.check_constraint "length(trim(title)) BETWEEN 1 AND 255", name: "chk_planner_items_title"
    t.check_constraint "priority BETWEEN 0 AND 3", name: "chk_planner_items_priority"
    t.check_constraint "record_type = 'Planner::Item'", name: "chk_planner_items_record_type"
    t.check_constraint "state <> 'cancelled' OR type = 'Planner::Event'", name: "chk_planner_items_cancelled_events"
    t.check_constraint "state IN ('active', 'abandoned', 'cancelled')", name: "chk_planner_items_state"
    t.check_constraint "tracks_done IN (0, 1)", name: "chk_planner_items_tracks_done"
    t.check_constraint "type = 'Planner::Event' OR tracks_done = 1", name: "chk_planner_items_done_always"
    t.check_constraint "type IN ('Planner::Event', 'Planner::Task', 'Planner::Todo')", name: "chk_planner_items_type"
  end

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
    t.datetime "deactivated_at"
    t.integer "day_start_hour", default: 7, null: false
    t.integer "day_end_hour", default: 21, null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
    t.check_constraint "date_format IN ('dmy', 'mdy', 'ymd')", name: "chk_users_date_format"
    t.check_constraint "day_end_hour BETWEEN 0 AND 23", name: "chk_users_day_end_hour"
    t.check_constraint "day_start_hour <= day_end_hour", name: "chk_users_day_hours_order"
    t.check_constraint "day_start_hour BETWEEN 0 AND 23", name: "chk_users_day_start_hour"
    t.check_constraint "email_address = lower(trim(email_address))", name: "chk_users_email_normalized"
    t.check_constraint "first_weekday BETWEEN 0 AND 6", name: "chk_users_first_weekday"
    t.check_constraint "locale GLOB '[a-z][a-z]'", name: "chk_users_locale_shape"
    t.check_constraint "role IN ('admin', 'user')", name: "chk_users_role"
    t.check_constraint "theme IN ('light', 'dark')", name: "chk_users_theme"
    t.check_constraint "time_format IN ('12h', '24h')", name: "chk_users_time_format"
  end

  add_foreign_key "core_entities", "users", on_delete: :cascade
  add_foreign_key "planner_items", "core_entities", column: ["id", "user_id", "record_type"], primary_key: ["id", "user_id", "record_type"], on_delete: :cascade
  add_foreign_key "sessions", "users", on_delete: :cascade
end
