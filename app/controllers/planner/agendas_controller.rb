# The same events as the calendar, read as lists: a month, a week or a day at a
# time.
class Planner::AgendasController < ApplicationController
  def show
    @period = Planner::Calendar::Period.new(view: params[:view], date: params[:date],
      first_weekday: effective_preferences.first_weekday, today: Date.current)
    @events_by_day = Planner::Event.owned_by(Current.user).kept.on_days(@period.range).group_by(&:day)
    @link_index = Core::LinkIndex.new(@events_by_day.values.flatten.map(&:id))
  end
end
