require "test_helper"

describe Planner::Recurrence::Delete do
  let(:user) { users(:member) }
  let(:rent) do
    Planner::Series.create!(user:, title: "Rent", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=MONTHLY;BYMONTHDAY=5",
      start_time: "09:00", duration_minutes: 60, tracks_done: 1)
  end

  def date(text) = Date.parse(text)

  def remove(series, on, scope)
    item = series.occurrence(date(on))
    [Planner::Recurrence::Delete.new(series:, item:, scope:).call, item]
  end

  def days(range = date("2026-10-01")..date("2027-03-31")) = Planner::Occurrences.for(user, range).map { |event| event.day.to_s }

  def trashed_event_days = Planner::Event.owned_by(user).trashed.includes(:entity).map { |event| event.day.to_s }.sort

  # A second part of the series, from December
  def split
    item = rent.occurrence(date("2026-12-05"))
    Planner::Recurrence::Edit.new(series: rent, item:, scope: "following", attributes: {title: "Rent 2", notes: "", priority: "normal", tracks_done: "1", day: "2026-12-05", start_time: "09:00", end_time: "10:00"},
      form: Planner::Recurrence::Form.from_rule(rent.rule)).call
    Planner::Series.where(chain_id: rent.id).sole
  end

  describe "this event" do
    it "skips the date for good: an unsaved occurrence is not drawn again, and no row is made" do
      assert_no_difference "Planner::Event.count" do
        ok, = remove(rent, "2026-11-05", "this")
        _(ok).must_equal true
      end
      _(days.first(3)).must_equal %w[2026-10-05 2026-12-05 2027-01-05]
    end

    it "trashes the row there is, and keeps the date skipped when the row is purged" do
      row = rent.materialize(date("2026-11-05"))
      remove(rent, "2026-11-05", "this")
      _(Planner::Event.includes(:entity).find(row.id)).must_be :trashed?
      Core::Entity.where(id: row.id).delete_all
      _(days.first(3)).must_equal %w[2026-10-05 2026-12-05 2027-01-05]
    end

    it "brings the date back with the row, when the row is restored" do
      row = rent.materialize(date("2026-11-05"))
      remove(rent, "2026-11-05", "this")
      Planner::Event.includes(:entity).find(row.id).restore
      _(days.first(3)).must_equal %w[2026-10-05 2026-11-05 2026-12-05]
    end

    it "skips a date once, however many times it is asked" do
      item = rent.occurrence(date("2026-11-05"))
      2.times { Planner::Recurrence::Delete.new(series: rent, item:, scope: "this").call }
      _(Planner::SeriesExclusion.where(series_id: rent.id).count).must_equal 1
    end
  end

  describe "this and following" do
    it "ends the series the day before, and trashes the rows from there on" do
      earlier = rent.materialize(date("2026-10-05"))
      later = rent.materialize(date("2026-12-05"))
      ok, = remove(rent, "2026-11-05", "following")
      _(ok).must_equal true
      _(rent.reload.ends_on).must_equal date("2026-11-04")
      _(days).must_equal %w[2026-10-05]
      _(Planner::Event.includes(:entity).find(earlier.id)).wont_be :trashed?
      _(Planner::Event.includes(:entity).find(later.id)).must_be :trashed?
    end

    it "trashes the later parts of the chain whole, with their rows" do
      later_part = split
      row = later_part.materialize(date("2027-01-05"))
      remove(rent, "2026-11-05", "following")
      _(later_part.reload).must_be :trashed?
      _(Planner::Event.includes(:entity).find(row.id)).must_be :trashed?
      _(days).must_equal %w[2026-10-05]
    end

    it "trashes the series itself when nothing would be left of it" do
      remove(rent, "2026-10-05", "following")
      _(rent.reload).must_be :trashed?
      _(days).must_equal []
    end
  end

  describe "this and past" do
    it "starts the series the day after, and trashes the rows up to there, done ones too" do
      done = rent.materialize(date("2026-10-05")).tap { |row| row.update!(done_at: Time.current) }
      rent.materialize(date("2026-12-05"))
      ok, = remove(rent, "2026-11-05", "past")
      _(ok).must_equal true
      _(rent.reload.from_on).must_equal date("2026-11-06")
      _(days.first(2)).must_equal %w[2026-12-05 2027-01-05]
      _(Planner::Event.includes(:entity).find(done.id)).must_be :trashed?
      _(trashed_event_days).must_equal %w[2026-10-05]
    end

    it "trashes the earlier parts of the chain whole" do
      later_part = split
      remove(later_part, "2027-01-05", "past")
      _(rent.reload).must_be :trashed?
      _(later_part.reload.from_on).must_equal date("2027-01-06")
    end

    it "finds the next date of a rule that gives one rarely, instead of trashing the whole series" do
      rare = Planner::Series.create!(user:, title: "Census", starts_on: date("2026-10-05"), time_zone: "Europe/Rome", rrule: "FREQ=YEARLY;INTERVAL=11;BYMONTH=10;BYMONTHDAY=5")
      remove(rare, "2026-10-05", "past")
      _(rare.reload).wont_be :trashed?
      _(rare.from_on).must_equal date("2026-10-06")
    end

    it "trashes the series itself when nothing would be left of it" do
      limited = Planner::Series.create!(user:, title: "Course", starts_on: date("2026-10-05"), time_zone: "Europe/Rome", rrule: "FREQ=WEEKLY;BYDAY=MO;COUNT=3")
      remove(limited, "2026-10-19", "past")
      _(limited.reload).must_be :trashed?
    end
  end

  describe "all events" do
    it "trashes every part of the chain and every kept row with one moment, leaving what was trashed before" do
      later_part = split
      earlier_row = rent.materialize(date("2026-10-05"))
      later_row = later_part.materialize(date("2027-01-05"))
      before = rent.materialize(date("2026-11-05"))
      remove(rent, "2026-11-05", "this")
      ok, = remove(rent, "2026-10-05", "all")
      _(ok).must_equal true
      moments = [rent.reload.deleted_at, later_part.reload.deleted_at, Planner::Event.includes(:entity).find(earlier_row.id).deleted_at, Planner::Event.includes(:entity).find(later_row.id).deleted_at]
      _(moments.uniq.size).must_equal 1
      _(moments.first).wont_be_nil
      _(Planner::Event.includes(:entity).find(before.id).deleted_at).wont_equal moments.first
      _(days).must_equal []
    end
  end

  it "says the series changed meanwhile, and changes nothing" do
    stale = Planner::Series.find(rent.id)
    rent.update!(title: "Changed")
    item = stale.occurrence(date("2026-11-05"))
    _(Planner::Recurrence::Delete.new(series: stale, item:, scope: "following").call).must_equal false
    _(item.errors).must_include :base
    _(rent.reload.ends_on).must_be_nil
  end

  it "does not know a scope it was not given" do
    _(-> { Planner::Recurrence::Delete.new(series: rent, item: rent.occurrence(date("2026-11-05")), scope: "some").call }).must_raise ArgumentError
  end

  describe "after a catch-up" do
    before do
      travel_to Time.utc(2026, 12, 10, 12)
      rent.catch_up(date("2026-12-09"))
    end

    def live_days = Planner::Event.owned_by(user).kept.where(series_id: rent.id).order(:day).pluck(:day).map(&:to_s)

    it "trashes the events from the cut on, and no later catch-up makes them again" do
      ok, = remove(rent, "2026-11-05", "following")
      _(ok).must_equal true
      _(live_days).must_equal %w[2026-10-05]
      _(Planner::Series.catch_up(user, today: date("2026-12-10"))).must_equal 0
      _(trashed_event_days).must_equal %w[2026-11-05 2026-12-05]
    end

    it "trashes the events up to the cut and keeps the later ones" do
      ok, = remove(rent, "2026-11-05", "past")
      _(ok).must_equal true
      _(live_days).must_equal %w[2026-12-05]
      _(Planner::Series.catch_up(user, today: date("2026-12-10"))).must_equal 0
    end
  end
end
