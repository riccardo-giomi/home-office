class AllowTasksInPlannerItems < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :planner_items, "type IN ('Planner::Event')", name: "chk_planner_items_type"
    add_check_constraint :planner_items, "type IN ('Planner::Event', 'Planner::Task')", name: "chk_planner_items_type"
    add_check_constraint :planner_items, "type = 'Planner::Event' OR tracks_done = 1", name: "chk_planner_items_done_always"
  end
end
