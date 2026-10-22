class AddPriorityAndPositionToPlannerItems < ActiveRecord::Migration[8.1]
  def up
    add_column :planner_items, :priority, :integer, default: 1, null: false
    add_check_constraint :planner_items, "priority BETWEEN 0 AND 3", name: "chk_planner_items_priority"

    # Nullable first, so the rows that exist get a place before the column
    # refuses NULL.
    add_column :planner_items, :position, :integer
    execute <<~SQL
      UPDATE planner_items SET position = (
        SELECT numbered.n FROM (
          SELECT id, ROW_NUMBER() OVER (PARTITION BY user_id, type ORDER BY id) AS n FROM planner_items
        ) numbered WHERE numbered.id = planner_items.id)
    SQL
    add_index :planner_items, %i[user_id type position], unique: true, name: "index_planner_items_position"
    change_column_null :planner_items, :position, false
  end

  def down
    remove_index :planner_items, name: "index_planner_items_position"
    remove_column :planner_items, :position
    remove_check_constraint :planner_items, name: "chk_planner_items_priority"
    remove_column :planner_items, :priority
  end
end
