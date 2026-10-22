class Planner::EventsController < Planner::ItemsController
  private

  def item_class = Planner::Event

  def permitted_attributes = [:title, :notes, :day, :start_time, :end_time, :tracks_done]
end
