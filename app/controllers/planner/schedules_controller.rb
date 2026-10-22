# The user's tasks, a day (the default: what is there to do today) or a week at
# a time, on a time grid.
class Planner::SchedulesController < ApplicationController
  def show
    @period = Planner::Calendar::Period.new(view: params[:view], date: params[:date], first_weekday: effective_preferences.first_weekday,
      today: Date.current, views: %i[day week], default: :day)
    @tasks_by_day = Planner::Task.owned_by(Current.user).on_days(@period.range).group_by(&:day)
  end
end
