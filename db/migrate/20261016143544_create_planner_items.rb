class CreatePlannerItems < ActiveRecord::Migration[8.1]
  def change
    # Class-table inheritance: the item's id is the id of its entity, which
    # supplies it when the item is saved
    create_table :planner_items do |t|
      t.integer :user_id, null: false
      t.string :record_type, null: false, default: "Planner::Item"
      t.string :type, null: false
      t.string :title, null: false
      t.text :notes
      t.date :day
      t.datetime :starts_at
      t.datetime :ends_at
      t.string :time_zone
      t.string :state, null: false, default: "active"
      t.integer :tracks_done, null: false, default: 0
      t.datetime :done_at
      t.timestamps

      t.foreign_key :core_entities, column: [:id, :user_id, :record_type], primary_key: [:id, :user_id, :record_type], on_delete: :cascade

      t.check_constraint "record_type = 'Planner::Item'", name: "chk_planner_items_record_type"
      t.check_constraint "type IN ('Planner::Event')", name: "chk_planner_items_type"
      t.check_constraint "length(trim(title)) BETWEEN 1 AND 255", name: "chk_planner_items_title"
      t.check_constraint "day IS NULL OR day = date(day)", name: "chk_planner_items_day_format"
      t.check_constraint "day IS NOT NULL OR type = 'Planner::Todo'", name: "chk_planner_items_day_required"
      t.check_constraint "(starts_at IS NULL) = (ends_at IS NULL) AND (starts_at IS NULL) = (time_zone IS NULL)", name: "chk_planner_items_times_paired"
      t.check_constraint "ends_at > starts_at", name: "chk_planner_items_window_order"
      t.check_constraint "state IN ('active', 'abandoned', 'cancelled')", name: "chk_planner_items_state"
      t.check_constraint "state <> 'cancelled' OR type = 'Planner::Event'", name: "chk_planner_items_cancelled_events"
      t.check_constraint "tracks_done IN (0, 1)", name: "chk_planner_items_tracks_done"
      t.check_constraint "done_at IS NULL OR tracks_done = 1", name: "chk_planner_items_done_tracked"
    end

    add_index :planner_items, [:user_id, :type, :day, :starts_at], name: "index_planner_items_on_day"
  end
end
