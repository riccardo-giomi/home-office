require "test_helper"

describe Planner::ImportantEvents do
  let(:user) { users(:admin) }
  let(:today) { Date.new(2026, 10, 9) }

  before { travel_to Time.utc(2026, 10, 9, 12) }

  def event(title, day: today, priority: "urgent", **attrs) = Planner::Event.create!({user:, title:, day:, priority:}.merge(attrs))

  def series(title, priority: "urgent", **attrs)
    Planner::Series.create!({user:, title:, priority:, starts_on: today - 20, time_zone: "Europe/Rome", rrule: "FREQ=DAILY"}.merge(attrs))
  end

  def titles(**options) = Planner::ImportantEvents.new(user, today:, **options).entries.map { |entry| [entry.title, entry.day.to_s] }

  describe "which events" do
    it "has the urgent ones from today to the horizon, earliest first" do
      event("Later", day: today + 6)
      event("Today")
      event("Past", day: today - 1)
      event("Beyond", day: today + 7)
      event("Normal", priority: "normal")
      event("High", priority: "high")
      _(titles).must_equal [["Today", "2026-10-09"], ["Later", "2026-10-15"]]
    end

    it "adds the high ones when asked for urgent and high" do
      event("High", priority: "high", day: today + 1)
      event("Urgent")
      _(titles(minimum: "high")).must_equal [["Urgent", "2026-10-09"], ["High", "2026-10-10"]]
    end

    it "widens with the horizon: thirty days, six months, a year" do
      event("Two weeks", day: today + 14)
      event("Three months", day: today + 90)
      event("Eleven months", day: today + 330)
      event("Two years", day: today + 730)
      _(titles).must_be :empty?
      _(titles(horizon: "30d").map(&:first)).must_equal ["Two weeks"]
      _(titles(horizon: "6m").map(&:first)).must_equal ["Two weeks", "Three months"]
      _(titles(horizon: "1y").map(&:first)).must_equal ["Two weeks", "Three months", "Eleven months"]
    end

    it "falls back to the defaults for a word it does not know" do
      event("Urgent")
      event("High", priority: "high")
      _(titles(horizon: "forever", minimum: "low")).must_equal [["Urgent", "2026-10-09"]]
    end

    it "leaves out what is done, abandoned, cancelled, in the trash, a task, a todo and another user's" do
      event("Done", tracks_done: 1, done_at: Time.current)
      event("Dropped").change_state("abandoned")
      event("Called off").change_state("cancelled")
      event("Trashed").trash
      Planner::Task.create!(user:, title: "A task", day: today, priority: "urgent")
      Planner::Todo.create!(user:, title: "A todo", priority: "urgent")
      Planner::Event.create!(user: users(:other_admin), title: "Not mine", day: today, priority: "urgent")
      _(titles).must_be :empty?
    end

    it "keeps an event that tracks done but is not done" do
      event("Pay", tracks_done: 1)
      _(titles).must_equal [["Pay", "2026-10-09"]]
    end
  end

  describe "a series" do
    it "shows once, with its nearest date" do
      series("Standup")
      _(titles).must_equal [["Standup", "2026-10-09"]]
    end

    it "shows the next date when the nearest one is done, abandoned or taken off" do
      daily = series("Standup", tracks_done: 1)
      daily.materialize(today).tap { |row| row.mark_done(true) }.save!
      _(titles).must_equal [["Standup", "2026-10-10"]]
      daily.materialize(today + 1).change_state("abandoned")
      _(titles).must_equal [["Standup", "2026-10-11"]]
      daily.exclusions.create!(user_id: user.id, excluded_on: today + 2)
      _(titles).must_equal [["Standup", "2026-10-12"]]
    end

    it "shows an urgent occurrence of a series that is not urgent, and only that one" do
      daily = series("Gym", priority: "normal")
      daily.materialize(today + 3).update!(priority: "urgent")
      _(titles).must_equal [["Gym", "2026-10-12"]]
    end

    it "does not show a series, or its rows, once the occurrence is made less important than the series" do
      daily = series("Gym")
      daily.materialize(today).update!(priority: "normal")
      _(titles).must_equal [["Gym", "2026-10-10"]]
    end

    it "is not shown when the series is not important enough, is in the trash or is another user's" do
      series("Normal", priority: "normal")
      series("Gone").tap { |gone| Planner::Series.where(id: gone.id).update_all(deleted_at: Time.current) }
      series("Theirs", user: users(:other_admin))
      _(titles).must_be :empty?
    end

    it "leaves out a series that has ended" do
      series("Over", ends_on: today - 1)
      _(titles).must_be :empty?
    end
  end

  describe "#count" do
    it "counts what the page would list" do
      event("One")
      event("Two", day: today + 2)
      series("Standup")
      _(Planner::ImportantEvents.new(user, today:).count).must_equal 3
    end
  end
end
