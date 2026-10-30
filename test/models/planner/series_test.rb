require "test_helper"

describe Planner::Series do
  let(:user) { users(:member) }
  let(:rrule) { "FREQ=WEEKLY;BYDAY=MO" }

  def build(**attrs)
    Planner::Series.new({user:, title: "Rent", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule:}.merge(attrs))
  end

  describe "validity" do
    it "needs only a title, an anchor day, a zone and a rule" do
      series = build
      _(series.save).must_equal true
      _([series.priority, series.tracks_done, series.lock_version, series.chain_id]).must_equal ["normal", 0, 0, nil]
    end

    it "strips the title and rejects a blank or too long one" do
      _(build(title: "  Rent ").tap(&:save!).title).must_equal "Rent"
      _(build(title: " ").tap(&:valid?).errors[:title]).wont_be_empty
      _(build(title: "a" * 256).tap(&:valid?).errors[:title]).wont_be_empty
    end

    it "rejects a rule that is not one of the offered ones" do
      ["FREQ=SECONDLY", "FREQ=DAILY;COUNT=5000", "", "nonsense"].each do |text|
        _(build(rrule: text).tap(&:valid?).errors[:rrule]).wont_be_empty
      end
    end

    it "reads and writes its rule as a Rule" do
      series = build(rrule: "FREQ=DAILY;INTERVAL=2")
      _(series.rule).must_equal Planner::Recurrence::Rule.new(frequency: "daily", interval: 2)
      series.rule = Planner::Recurrence::Rule.new(frequency: "yearly", month: 2, month_day: 1)
      _(series.rrule).must_equal "FREQ=YEARLY;BYMONTH=2;BYMONTHDAY=1"
    end

    it "rejects an unknown zone and a span that ends before it starts" do
      _(build(time_zone: "Mars/Olympus").tap(&:valid?).errors[:time_zone]).wont_be_empty
      _(build(ends_on: Date.new(2026, 10, 4)).tap(&:valid?).errors[:ends_on]).wont_be_empty
      _(build(from_on: Date.new(2026, 10, 4)).tap(&:valid?).errors[:from_on]).wont_be_empty
      _(build(ends_on: Date.new(2026, 10, 5), from_on: Date.new(2026, 10, 6)).tap(&:valid?).errors[:from_on]).wont_be_empty
    end

    it "keeps a start time and a duration together, the duration positive" do
      _(build(start_time: "09:30", duration_minutes: 45)).must_be :valid?
      _(build(start_time: "09:30").tap(&:valid?).errors[:duration_minutes]).wont_be_empty
      _(build(duration_minutes: 30).tap(&:valid?).errors[:start_time]).wont_be_empty
      _(build(start_time: "9:30", duration_minutes: 30).tap(&:valid?).errors[:start_time]).wont_be_empty
      _(build(start_time: "09:30", duration_minutes: 0).tap(&:valid?).errors[:duration_minutes]).wont_be_empty
    end

    it "ends on the day it starts, as an event does" do
      _(build(start_time: "23:00", duration_minutes: 60)).must_be :valid?
      _(build(start_time: "23:00", duration_minutes: 61).tap(&:valid?).errors[:duration_minutes]).wont_be_empty
    end
  end

  describe "chains" do
    it "is its own chain when alone" do
      series = build.tap(&:save!)
      _(series.chain).must_equal [series]
      _(series.chain_key).must_equal series.id
    end

    it "gathers the segments that came from the same first series" do
      first = build.tap(&:save!)
      second = build(chain_id: first.id, starts_on: Date.new(2026, 11, 5)).tap(&:save!)
      other = build.tap(&:save!)
      _(first.chain).must_equal [first, second]
      _(second.chain).must_equal [first, second]
      _(other.chain).must_equal [other]
    end

    it "refuses a chain that belongs to another user" do
      foreign = Planner::Series.create!(user: users(:other_admin), title: "Theirs", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule:)
      _(-> { build(chain_id: foreign.id).save!(validate: false) }).must_raise ActiveRecord::InvalidForeignKey
    end
  end

  describe "what the database refuses with validations bypassed" do
    it "a cross-user exclusion, a duplicate, an occurrence of a task" do
      series = build.tap(&:save!)
      _(-> { Planner::SeriesExclusion.new(series_id: series.id, user_id: users(:admin).id, excluded_on: Date.new(2026, 10, 12)).save!(validate: false) }).must_raise ActiveRecord::InvalidForeignKey
      series.exclusions.create!(user_id: series.user_id, excluded_on: Date.new(2026, 10, 12))
      _(-> { series.exclusions.new(user_id: series.user_id, excluded_on: Date.new(2026, 10, 12)).save!(validate: false) }).must_raise ActiveRecord::RecordNotUnique
      event = Planner::Event.create!(user:, title: "Rent", day: Date.new(2026, 10, 5), series:, occurrence_on: Date.new(2026, 10, 5))
      _(event).must_be :occurrence?
      _(-> { Planner::Event.new(user:, title: "Again", day: Date.new(2026, 10, 5), series:, occurrence_on: Date.new(2026, 10, 5)).save!(validate: false) }).must_raise ActiveRecord::RecordNotUnique
      _(-> { Planner::Task.create!(user:, title: "Not an event", day: Date.new(2026, 10, 5), series:, occurrence_on: Date.new(2026, 10, 5)) }).must_raise ActiveRecord::CheckViolation
      _(-> { Planner::Event.create!(user:, title: "Half", day: Date.new(2026, 10, 5), series:) }).must_raise ActiveRecord::CheckViolation
    end

    it "deleting a series takes its exclusions and leaves no orphan" do
      series = build.tap(&:save!)
      series.exclusions.create!(user_id: series.user_id, excluded_on: Date.new(2026, 10, 12))
      series.destroy!
      _(Planner::SeriesExclusion.where(series_id: series.id)).must_be :empty?
    end
  end

  it "goes to the trash and back like an entity" do
    series = build.tap(&:save!)
    series.trash
    _(Planner::Series.kept).wont_include series
    _(Planner::Series.trashed).must_include series
    series.restore
    _(Planner::Series.kept).must_include series
  end

  describe ".from_event" do
    let(:rule) { Planner::Recurrence::Rule.new(frequency: "weekly", weekdays: %w[MO]) }

    it "takes the template, the anchor and the times from a valid event" do
      event = Planner::Event.new(user:, title: "Gym", notes: "Towel", priority: "high", tracks_done: 1, day: Date.new(2026, 10, 5), start_time: "18:00", end_time: "19:30")
      event.validate
      series = Planner::Series.from_event(event, rule)
      _(series).must_be :valid?
      _([series.user_id, series.title, series.notes, series.priority, series.tracks_done, series.starts_on, series.start_time, series.duration_minutes, series.rrule, series.time_zone])
        .must_equal [user.id, "Gym", "Towel", "high", 1, Date.new(2026, 10, 5), "18:00", 90, "FREQ=WEEKLY;BYDAY=MO", event.time_zone]
    end

    it "is all-day when the event is, in the zone of the request" do
      event = Planner::Event.new(user:, title: "Holiday", day: Date.new(2026, 10, 5))
      event.validate
      series = Time.use_zone("Asia/Tokyo") { Planner::Series.from_event(event, rule) }
      _([series.start_time, series.duration_minutes, series.time_zone]).must_equal [nil, nil, "Asia/Tokyo"]
      _(series).must_be :valid?
    end
  end
end
