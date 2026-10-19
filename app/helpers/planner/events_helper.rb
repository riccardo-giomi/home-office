module Planner::EventsHelper
  # In the dialog the page lives in the frame the dialog holds; a full page
  # needs no frame (its own forms and links must not be captured by one).
  def event_frame(&block) = in_dialog? ? turbo_frame_tag(Planner::EventDialog::FRAME_ID, &block) : capture(&block)

  # Where "Back" goes: the calendar or agenda page the visit began on, else the
  # calendar around the event.
  def event_back_href(event) = back_param || planner_calendar_path(date: event.day&.iso8601)

  def event_back_label = t("planner.events.back.#{back_location&.page || :calendar}")
end
