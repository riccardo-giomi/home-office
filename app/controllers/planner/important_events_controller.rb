# Lists the urgent events (or the urgent and high ones) from today to a horizon.
# It is a tab of the agenda, after the views of the period.
class Planner::ImportantEventsController < ApplicationController
  def index
    @important_events = Planner::ImportantEvents.new(
      Current.user, today: Date.current, horizon: params[:horizon], minimum: params[:minimum]
    )
    @events_by_day = @important_events.entries.group_by(&:day)
    @link_index = Core::LinkIndex.new(@important_events.entries.filter_map(&:id))
  end
end
