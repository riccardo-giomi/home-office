class Planner::TasksController < Planner::ItemsController
  private

  def item_class = Planner::Task

  def permitted_attributes = super + [:day, :start_time, :end_time]
end
