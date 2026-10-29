class CreatePlannerSeries < ActiveRecord::Migration[8.1]
  def change
    create_table :planner_series do |t|
      t.references :user, null: false, foreign_key: {on_delete: :cascade}, index: false
      t.integer :chain_id
      t.string :title, null: false
      t.text :notes
      t.integer :priority, null: false, default: 1
      t.date :starts_on, null: false
      t.date :from_on
      t.date :ends_on
      t.integer :tracks_done, null: false, default: 0
      t.string :start_time
      t.integer :duration_minutes
      t.string :time_zone, null: false
      t.string :rrule, null: false
      t.integer :lock_version, null: false, default: 0
      t.datetime :deleted_at
      t.timestamps
      t.index [:id, :user_id], unique: true
      t.index [:user_id, :chain_id]
      t.index [:user_id, :deleted_at], where: "deleted_at IS NOT NULL", name: "index_planner_series_trash"
      t.check_constraint "length(trim(title)) BETWEEN 1 AND 255", name: "chk_planner_series_title"
      t.check_constraint "priority BETWEEN 0 AND 3", name: "chk_planner_series_priority"
      t.check_constraint "tracks_done IN (0, 1)", name: "chk_planner_series_tracks_done"
      t.check_constraint "(start_time IS NULL) = (duration_minutes IS NULL) AND (duration_minutes IS NULL OR duration_minutes > 0)", name: "chk_planner_series_times"
      t.check_constraint "start_time IS NULL OR start_time GLOB '[0-2][0-9]:[0-5][0-9]'", name: "chk_planner_series_start_time"
      t.check_constraint "ends_on IS NULL OR ends_on >= starts_on", name: "chk_planner_series_ends"
      t.check_constraint "from_on IS NULL OR from_on >= starts_on", name: "chk_planner_series_from"
      t.check_constraint "starts_on = date(starts_on) AND (from_on IS NULL OR from_on = date(from_on)) AND (ends_on IS NULL OR ends_on = date(ends_on))", name: "chk_planner_series_date_format"
      t.check_constraint "length(rrule) BETWEEN 1 AND 255", name: "chk_planner_series_rrule"
    end
    add_foreign_key :planner_series, :planner_series, column: [:chain_id, :user_id], primary_key: [:id, :user_id]

    create_table :planner_series_exclusions do |t|
      t.integer :series_id, null: false
      t.integer :user_id, null: false
      t.date :excluded_on, null: false
      t.index [:series_id, :excluded_on], unique: true
      t.check_constraint "excluded_on = date(excluded_on)", name: "chk_planner_series_exclusions_date_format"
    end
    add_foreign_key :planner_series_exclusions, :planner_series, column: [:series_id, :user_id], primary_key: [:id, :user_id], on_delete: :cascade

    add_column :planner_items, :series_id, :integer
    add_column :planner_items, :occurrence_on, :date
    add_index :planner_items, [:series_id, :occurrence_on], unique: true
    add_foreign_key :planner_items, :planner_series, column: [:series_id, :user_id], primary_key: [:id, :user_id]
    add_check_constraint :planner_items, "(series_id IS NULL) = (occurrence_on IS NULL)", name: "chk_planner_items_series_pair"
    add_check_constraint :planner_items, "series_id IS NULL OR type = 'Planner::Event'", name: "chk_planner_items_series_events"
    add_check_constraint :planner_items, "occurrence_on IS NULL OR occurrence_on = date(occurrence_on)", name: "chk_planner_items_occurrence_format"
  end
end
