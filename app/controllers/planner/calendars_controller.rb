class Planner::CalendarsController < ApplicationController
  def show
    @period = Planner::Calendar::Period.new(view: params[:view], date: params[:date],
      first_weekday: effective_preferences.first_weekday, today: Date.current, hours: params[:hours])
    @events_by_day = Planner::Occurrences.for(Current.user, @period.grid_range).group_by(&:day)
    @link_index = Core::LinkIndex.new(@events_by_day.values.flatten.filter_map(&:id))
  end
end
