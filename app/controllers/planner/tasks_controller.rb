class Planner::TasksController < Planner::ItemsController
  private

  def item_class = Planner::Task

  def permitted_attributes = [:title, :notes, :day, :start_time, :end_time]
end
