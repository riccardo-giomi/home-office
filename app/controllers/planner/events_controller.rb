class Planner::EventsController < Planner::ItemsController
  private

  def item_class = Planner::Event

  def permitted_attributes = super + [:day, :start_time, :end_time, :tracks_done]
end
