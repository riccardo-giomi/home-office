# Builds the Planner cards of the home page: Events, Tasks and Todos.
#
# Each card has a few counts and links to the lists they count.
#
# The counts come from Planner::Counts, the object that the sidebar uses too,
# so each number is queried once for a request.
module Planner::Dashboard
  Line = Core::DashboardLine
  Card = Core::DashboardCard

  def self.cards(user, today)
    counts = Planner::Counts.for(user)
    routes = Rails.application.routes.url_helpers
    day = today.iso8601
    [
      Card.new(
        title_key: "planner.dashboard.events.title",
        href: routes.planner_calendar_path, narrow_href: routes.planner_agenda_path,
        lines: [
          Line.new(
            label_key: "planner.dashboard.events.this_week", count: counts.events_week,
            href: routes.planner_calendar_path(view: "week", date: day),
            narrow_href: routes.planner_agenda_path(view: "week", date: day)
          ),
          Line.new(
            label_key: "planner.dashboard.events.today", count: counts.events_today,
            href: routes.planner_calendar_path(view: "day", date: day)
          ),
          Line.new(
            label_key: "planner.dashboard.events.important", count: counts.important,
            href: routes.planner_important_events_path
          ),
          Line.new(
            label_key: "planner.dashboard.events.missed", count: counts.missed,
            href: routes.planner_missed_events_path
          )
        ]
      ),
      Card.new(
        title_key: "planner.dashboard.tasks.title",
        href: routes.planner_schedule_path,
        narrow_href: routes.planner_schedule_path(view: "day", date: day),
        lines: [
          Line.new(
            label_key: "planner.dashboard.tasks.today", count: counts.tasks_today,
            href: routes.planner_schedule_path(view: "day", date: day)
          ),
          Line.new(
            label_key: "planner.dashboard.tasks.this_week", count: counts.tasks_week,
            href: routes.planner_schedule_path(view: "week", date: day),
            narrow_href: routes.planner_schedule_path(view: "day", date: day)
          ),
          Line.new(
            label_key: "planner.dashboard.tasks.forgotten", count: counts.forgotten,
            href: routes.planner_forgotten_tasks_path
          )
        ]
      ),
      Card.new(
        title_key: "planner.dashboard.todos.title", href: routes.planner_todos_path,
        total: counts.todos, total_key: "planner.dashboard.todos.total",
        lines: [
          Line.new(
            label_key: "planner.dashboard.todos.urgent", count: counts.todos_urgent,
            href: routes.planner_todos_path
          )
        ]
      )
    ]
  end
end
