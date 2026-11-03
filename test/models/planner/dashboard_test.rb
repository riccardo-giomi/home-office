require "test_helper"

describe Planner::Dashboard do
  let(:user) { users(:admin) }
  let(:other) { users(:member) }
  let(:routes) { Rails.application.routes.url_helpers }
  let(:now) { Time.utc(2026, 10, 8, 2) }

  before do
    Planner::Item.delete_all
    Planner::Series.delete_all
    Current.reset
    Current.first_weekday = 1
    travel_to now
    Time.zone = "America/New_York"
  end

  after { Time.zone = "UTC" }

  def today = Date.current

  def cards = Planner::Dashboard.cards(user, today)

  def card(key) = cards.find { |one| one.title_key == "planner.dashboard.#{key}.title" }

  def line(key, label) = card(key).lines.find { |one| one.label_key == "planner.dashboard.#{key}.#{label}" }

  it "has the cards Events, Tasks and Todos, in that order, for a user with nothing, every line at zero" do
    _(cards.map(&:title_key)).must_equal %w[planner.dashboard.events.title planner.dashboard.tasks.title planner.dashboard.todos.title]
    _(cards.flat_map { |one| one.lines.map(&:count) }).must_equal [0, 0, 0, 0, 0, 0, 0, 0]
  end

  it "has the Events lines in order, with the places they go to" do
    _(card("events").lines.map(&:label_key)).must_equal %w[this_week today important missed].map { |key| "planner.dashboard.events.#{key}" }
    _(card("events").href).must_equal routes.planner_calendar_path
    _(card("events").narrow_href).must_equal routes.planner_agenda_path
    week = line("events", "this_week")
    _(week.href).must_equal routes.planner_calendar_path(view: "week", date: today.iso8601)
    _(week.narrow_href).must_equal routes.planner_agenda_path(view: "week", date: today.iso8601)
    _(line("events", "today").href).must_equal routes.planner_calendar_path(view: "day", date: today.iso8601)
    _(line("events", "important").href).must_equal routes.planner_important_events_path
    _(line("events", "missed").href).must_equal routes.planner_missed_events_path
  end

  it "has the Tasks lines in order, the week going to the day on a narrow screen" do
    _(card("tasks").lines.map(&:label_key)).must_equal %w[today this_week forgotten].map { |key| "planner.dashboard.tasks.#{key}" }
    _(card("tasks").href).must_equal routes.planner_schedule_path
    _(card("tasks").narrow_href).must_equal routes.planner_schedule_path(view: "day", date: today.iso8601)
    _(line("tasks", "today").href).must_equal routes.planner_schedule_path(view: "day", date: today.iso8601)
    _(line("tasks", "this_week").href).must_equal routes.planner_schedule_path(view: "week", date: today.iso8601)
    _(line("tasks", "this_week").narrow_href).must_equal routes.planner_schedule_path(view: "day", date: today.iso8601)
    _(line("tasks", "forgotten").href).must_equal routes.planner_forgotten_tasks_path
  end

  it "has the Todos total with an Urgent line, both going to the list" do
    todo = card("todos")
    _(todo.href).must_equal routes.planner_todos_path
    _(todo.lines.map(&:label_key)).must_equal ["planner.dashboard.todos.urgent"]
    _(todo.lines.first.href).must_equal routes.planner_todos_path
  end

  it "counts what the lists it links to hold, for the user's own and on the user's day" do
    Planner::Event.create!(user:, title: "Today", day: today, priority: "urgent")
    Planner::Event.create!(user:, title: "Missed", day: today - 2, tracks_done: 1)
    Planner::Event.create!(user:, title: "Yesterday", day: today - 1)
    Planner::Event.create!(user: other, title: "Theirs", day: today, priority: "urgent")
    Planner::Event.create!(user:, title: "Gone", day: today).trash
    Planner::Task.create!(user:, title: "Today task", day: today)
    Planner::Task.create!(user:, title: "Old task", day: today - 3)
    Planner::Task.create!(user: other, title: "Their task", day: today)
    Planner::Todo.create!(user:, title: "Urgent", priority: "urgent")
    Planner::Todo.create!(user:, title: "Plain")
    _(line("events", "today").count).must_equal 1
    _(line("events", "this_week").count).must_equal 3
    _(line("events", "important").count).must_equal 1
    _(line("events", "missed").count).must_equal 1
    _(line("tasks", "today").count).must_equal 1
    _(line("tasks", "this_week").count).must_equal 1
    _(line("tasks", "forgotten").count).must_equal 1
    _(card("todos").total).must_equal 2
    _(line("todos", "urgent").count).must_equal 1
  end

  it "asks the same number of questions of planner_items however many items there are" do
    def questions
      Planner::Counts.reset
      count = 0
      callback = ->(*, payload) { count += 1 if payload[:sql].include?("planner_items") && !payload[:cached] }
      ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { Planner::Dashboard.cards(user, today) }
      count
    end
    3.times { |i| Planner::Event.create!(user:, title: "E#{i}", day: today) }
    few = questions
    60.times { |i| Planner::Task.create!(user:, title: "T#{i}", day: today) }
    _(questions).must_equal few
  end
end
