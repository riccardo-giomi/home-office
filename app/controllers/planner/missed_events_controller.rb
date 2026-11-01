# Lists the events that track done, are not done and are dated before today.
# From the list, an event can be marked done, given a new day or abandoned.
#
# The list needs the past occurrences of series saved as events, so this
# controller runs the catch-up itself, whatever HOME_OFFICE_CATCH_UP is set to.
class Planner::MissedEventsController < ApplicationController
  include Planner::PagedAgendaList

  private

  def items
    Planner::CatchUp.run(Current.user, today: Date.current)
    Planner::Event.owned_by(Current.user).missed(Date.current)
  end

  def back_path = planner_calendar_path
end
