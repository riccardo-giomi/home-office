class Planner::CalendarsController < ApplicationController
  def show
    @period = Planner::Calendar::Period.new(view: params[:view], date: params[:date],
      first_weekday: effective_preferences.first_weekday, today: Date.current)
    @events_by_day = Planner::Event.owned_by(Current.user).kept.on_days(@period.grid_range).group_by(&:day)
  end
end
