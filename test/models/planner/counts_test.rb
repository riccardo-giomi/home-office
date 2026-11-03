require "test_helper"

describe Planner::Counts do
  let(:user) { users(:admin) }
  let(:other) { users(:member) }
  # 22:00 on Wed 7 Oct in New York is already Thu 8 Oct in UTC
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

  def counts(first_weekday: 1)
    Current.first_weekday = first_weekday
    Planner::Counts.reset
    Planner::Counts.for(user)
  end

  def event(title = "E", day: today, owner: user, **attrs) = Planner::Event.create!({user: owner, title:, day:}.merge(attrs))

  def task(title = "T", day: today, owner: user, **attrs) = Planner::Task.create!({user: owner, title:, day:}.merge(attrs))

  def todo(title = "D", owner: user, **attrs) = Planner::Todo.create!({user: owner, title:}.merge(attrs))

  it "takes today from the user's zone, not UTC" do
    event("Today")
    event("Tomorrow in UTC", day: today + 1)
    _(counts.events_today).must_equal 1
  end

  describe "events" do
    it "counts active, kept events of today, done or not, and nobody else's" do
      event("Plain")
      event("Done", tracks_done: 1, done_at: Time.current)
      event("Abandoned", state: "abandoned")
      event("Cancelled", state: "cancelled")
      event("Trashed").trash
      event("Tomorrow", day: today + 1)
      event("Theirs", owner: other)
      _(counts.events_today).must_equal 2
    end

    it "counts an unsaved occurrence of a series" do
      Planner::Series.create!(user:, title: "Daily", starts_on: today, time_zone: "America/New_York", rrule: "FREQ=DAILY")
      _(counts.events_today).must_equal 1
    end

    it "follows the week from the first weekday" do
      2.times { |i| event("Sunday #{i}", day: Date.new(2026, 10, 4)) }
      event("Next Sunday", day: Date.new(2026, 10, 11))
      _(counts(first_weekday: 1).events_week).must_equal 1
      _(counts(first_weekday: 0).events_week).must_equal 2
    end
  end

  describe "tasks" do
    it "counts active, kept, not done tasks of the day and the week, not events or todos" do
      task("Today")
      task("Done", done_at: Time.current)
      task("Abandoned", state: "abandoned")
      task("Tomorrow", day: today + 1)
      task("Theirs", owner: other)
      event("Event")
      todo
      _(counts.tasks_today).must_equal 1
      _(counts.tasks_week).must_equal 2
    end
  end

  describe "todos" do
    it "counts active not done todos, and the urgent ones" do
      todo("Normal")
      todo("Urgent", priority: "urgent")
      todo("Done urgent", priority: "urgent", done_at: Time.current)
      todo("Theirs", owner: other, priority: "urgent")
      _(counts.todos).must_equal 2
      _(counts.todos_urgent).must_equal 1
    end
  end

  describe "the lists" do
    it "counts the forgotten tasks, with today taken from the user's zone, not UTC" do
      task("Yesterday", day: today - 1)
      task("Today")
      _(counts.forgotten).must_equal 1
      _(counts.forgotten).must_equal Planner::Task.owned_by(user).forgotten(today).count
    end

    it "counts the missed events" do
      event("Missed", day: today - 2, tracks_done: 1)
      _(counts.missed).must_equal 1
      _(counts.missed).must_equal Planner::Event.owned_by(user).missed(today).count
    end

    it "counts the important events" do
      event("Urgent", priority: "urgent")
      _(counts.important).must_equal 1
      _(counts.important).must_equal Planner::ImportantEvents.new(user, today:).count
    end
  end

  describe "sharing" do
    it "is the same object twice in a request, a new one after a reset" do
      first = Planner::Counts.for(user)
      _(Planner::Counts.for(user)).must_be_same_as first
      Planner::Counts.reset
      _(Planner::Counts.for(user)).wont_be_same_as first
    end

    it "asks the database once for a number asked twice" do
      c = counts
      c.todos
      queries = count_queries { 2.times { c.todos_urgent } }
      _(queries).must_equal 1
    end
  end

  def count_queries(&)
    count = 0
    callback = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &)
    count
  end
end
