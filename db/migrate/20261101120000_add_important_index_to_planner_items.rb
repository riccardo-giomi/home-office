class AddImportantIndexToPlannerItems < ActiveRecord::Migration[8.1]
  # Index for the Important list: user and type, then priority, then day.
  def change
    add_index :planner_items, %i[user_id type priority day], name: "index_planner_items_important"
  end
end
