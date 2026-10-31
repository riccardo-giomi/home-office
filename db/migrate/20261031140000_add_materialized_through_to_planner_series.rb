class AddMaterializedThroughToPlannerSeries < ActiveRecord::Migration[8.1]
  # The last day whose occurrences were saved as events, or NULL if none were. A
  # date after it that has no event is an unsaved occurrence.
  def change
    add_column :planner_series, :materialized_through, :date
    add_check_constraint :planner_series,
      "materialized_through IS NULL OR materialized_through = date(materialized_through)",
      name: "chk_planner_series_materialized_format"
  end
end
