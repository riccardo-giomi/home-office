class AllowTodosInPlannerItems < ActiveRecord::Migration[8.1]
  def change
    remove_check_constraint :planner_items, "type IN ('Planner::Event', 'Planner::Task')", name: "chk_planner_items_type"
    add_check_constraint :planner_items, "type IN ('Planner::Event', 'Planner::Task', 'Planner::Todo')", name: "chk_planner_items_type"
  end
end
