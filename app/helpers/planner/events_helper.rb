module Planner::EventsHelper
  # The choice of events to list, as the tabs component wants it: [label, href, current?]
  def event_views
    [
      [t("planner.events.index.upcoming"), planner_events_path, @when == :upcoming],
      [t("planner.events.index.past"), planner_events_path(when: "past"), @when == :past]
    ]
  end
end
