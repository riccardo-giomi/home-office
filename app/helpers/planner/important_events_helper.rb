# The Important tab of the agenda, and the horizon and minimum priority choices
# of the Important page.
module Planner::ImportantEventsHelper
  # Returns [label, href, current?] for the strip of tabs. The label has a badge
  # with the number of important events for the default horizon and minimum.
  def important_events_tab(current: false)
    count = Planner::Counts.for(Current.user).important
    label = safe_join([
      t("planner.important_events.tab"),
      render(Core::UI::BadgeComponent.new(count:, label: t("planner.nav.important_events_badge", count:)))
    ])
    [label, planner_important_events_path, current]
  end

  # Returns the views of the agenda as links to the agenda page, followed by the
  # Important tab marked as current.
  def agenda_views_with_important_events
    views = Planner::Calendar::Period::VIEWS.map do |view|
      [t("planner.periods.views.#{view}"), planner_agenda_path(view:), false]
    end
    views + [important_events_tab(current: true)]
  end

  def important_events_horizon_items(important_events)
    Planner::ImportantEvents::HORIZONS.map do |horizon|
      [
        t("planner.important_events.horizons.#{horizon}"),
        planner_important_events_path(horizon:, minimum: important_events.minimum),
        important_events.horizon == horizon
      ]
    end
  end

  def important_events_minimum_items(important_events)
    Planner::ImportantEvents::MINIMUMS.keys.map do |minimum|
      [
        t("planner.important_events.minimums.#{minimum}"),
        planner_important_events_path(horizon: important_events.horizon, minimum:),
        important_events.minimum == minimum
      ]
    end
  end
end
