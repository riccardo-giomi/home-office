module Planner::EventsHelper
  # Where "Back" goes: the calendar or agenda page the visit began on, else the
  # calendar around the event.
  def event_back_href(event) = back_param || planner_calendar_path(date: event.day&.iso8601)

  def event_back_label = t("planner.events.back.#{back_location&.page || :calendar}")
end
