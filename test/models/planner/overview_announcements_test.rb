require "test_helper"

describe "What tells the home page that a number changed" do
  let(:user) { users(:admin) }
  let(:other) { users(:member) }
  let(:today) { Date.new(2026, 10, 9) }

  before do
    Planner::Item.delete_all
    Planner::Series.delete_all
    Current.reset
    travel_to Time.utc(2026, 10, 9, 12)
  end

  def broadcasts_during(owner = user, &) = capture_turbo_stream_broadcasts(Core::Overview.stream(owner.id), &).size

  def event(title = "E", owner: user, **attrs) = Planner::Event.create!({user: owner, title:, day: today}.merge(attrs))

  def series(**attrs) = Planner::Series.create!({user:, title: "Daily", starts_on: today, time_zone: "UTC", rrule: "FREQ=DAILY"}.merge(attrs))

  describe "an item" do
    it "is told when one is made or destroyed" do
      item = nil
      _(broadcasts_during { item = event }).must_equal 1
      _(broadcasts_during { item.destroy! }).must_equal 1
    end

    it "is told when a todo is made, which has no day" do
      _(broadcasts_during { Planner::Todo.create!(user:, title: "No day") }).must_equal 1
    end

    it "is told of each change to something the counts read" do
      item = event
      {day: today + 1, priority: "urgent", state: "abandoned", tracks_done: 1}.each do |column, value|
        _(broadcasts_during { item.update!(column => value) }).must_equal 1, column
      end
      _(broadcasts_during { item.update!(done_at: Time.current) }).must_equal 1
    end

    it "is not told of a change to something the counts do not read" do
      item = event
      _(broadcasts_during { item.update!(title: "Another", notes: "Something") }).must_equal 0
    end

    it "is told when an item goes to the trash and comes back" do
      item = event
      _(broadcasts_during { item.trash }).must_equal 1
      _(broadcasts_during { item.restore }).must_equal 1
    end

    it "tells the owner and nobody else" do
      _(broadcasts_during(user) { event(owner: other) }).must_equal 0
      _(broadcasts_during(other) { event(owner: other) }).must_equal 1
    end
  end

  describe "an occurrence of a series" do
    it "is not told when one is saved as it was drawn" do
      daily = series
      _(broadcasts_during { daily.materialize(today + 1) }).must_equal 0
    end

    it "is told when one is saved as cancelled, or on another day" do
      daily = series
      cancelled = daily.occurrence(today + 1)
      cancelled.state = "cancelled"
      _(broadcasts_during { cancelled.save! }).must_equal 1
      moved = daily.occurrence(today + 2)
      moved.day = today + 4
      _(broadcasts_during { moved.save! }).must_equal 1
    end

    it "is told when one is saved late and not done, which makes it a missed event" do
      daily = series(starts_on: today - 3, tracks_done: 1)
      late = daily.occurrence(today - 1)
      _(broadcasts_during { late.save! }).must_equal 1
    end
  end

  describe "a series" do
    it "is told when one is made, changed or destroyed" do
      daily = nil
      _(broadcasts_during { daily = series }).must_equal 1
      _(broadcasts_during { daily.update!(title: "Every day") }).must_equal 1
      _(broadcasts_during { daily.destroy! }).must_equal 1
    end
  end

  describe "a write that runs no callbacks" do
    it "is told once when the catch-up makes the missed events" do
      tracked = series(starts_on: today - 3, tracks_done: 1)
      _(broadcasts_during { tracked.catch_up(today - 1) }).must_equal 1
    end

    it "is told when a series is deleted with all its events, and when it is restored" do
      daily = series
      _(broadcasts_during { Planner::Recurrence::Delete.new(series: daily, item: daily.occurrence(today), scope: "all").call }).must_be :>=, 1
      _(broadcasts_during { daily.reload.restore_group }).must_equal 1
    end

    it "is told when the trash is emptied" do
      event.trash
      series.tap { |daily| Planner::Recurrence::Delete.new(series: daily, item: daily.occurrence(today), scope: "all").call }
      _(broadcasts_during { Planner::Trash.new(user).empty! }).must_be :>=, 1
    end

    it "is told when what stayed too long in the trash is purged" do
      event.trash
      _(broadcasts_during { Core::Entity.purge_expired(Time.current + 31.days) }).must_equal 1
    end

    it "is told when a series in the trash is purged" do
      daily = series
      Planner::Recurrence::Delete.new(series: daily, item: daily.occurrence(today), scope: "all").call
      _(broadcasts_during { Planner::Series.purge(Planner::Series.owned_by(user).trashed) }).must_equal 1
    end
  end
end
