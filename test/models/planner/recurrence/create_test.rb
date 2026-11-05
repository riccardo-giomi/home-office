require "test_helper"

describe Planner::Recurrence::Create do
  let(:user) { users(:member) }

  def event(**attrs) = Planner::Event.new({user:, title: "Gym", day: Date.new(2026, 10, 5), start_time: "18:00", end_time: "19:00", priority: "high", tracks_done: 1}.merge(attrs))

  def form(**attrs) = Planner::Recurrence::Form.new(frequency: "weekly", weekdays: %w[MO WE], ends: "never", **attrs)

  it "makes a series from the event and the repeat fields, and no event" do
    event = event()
    series = Planner::Recurrence::Create.new(event:, form: form).call
    _(series).must_be_kind_of Planner::Series
    _(series).must_be :persisted?
    _([series.title, series.priority, series.tracks_done, series.start_time, series.duration_minutes, series.rrule]).must_equal ["Gym", "high", 1, "18:00", 60, "FREQ=WEEKLY;BYDAY=MO,WE"]
    _(Planner::Event.where(series_id: series.id).count).must_equal 0
    _(event).wont_be :persisted?
  end

  it "follows the day when the repeat leaves the weekday to the rule" do
    series = Planner::Recurrence::Create.new(event: event, form: form(weekdays: [])).call
    _(series.rrule).must_equal "FREQ=WEEKLY;BYDAY=MO"
  end

  it "refuses an invalid event, with the event's errors, and makes nothing" do
    event = event(title: "")
    _(Planner::Recurrence::Create.new(event:, form: form).call).must_equal false
    _(event.errors[:title]).wont_be :empty?
    _(Planner::Series.where(user:).count).must_equal 0
  end

  it "refuses an invalid rule, with the form's errors" do
    form = form(frequency: "weekly", interval: 0)
    _(Planner::Recurrence::Create.new(event: event, form:).call).must_equal false
    _(form.errors[:interval]).wont_be :empty?
  end

  it "refuses an event with no day" do
    event = event(day: nil)
    _(Planner::Recurrence::Create.new(event:, form: form).call).must_equal false
    _(event.errors[:day]).wont_be :empty?
  end

  it "refuses a form that does not repeat" do
    _(Planner::Recurrence::Create.new(event: event, form: form(frequency: "never")).call).must_equal false
  end
end
