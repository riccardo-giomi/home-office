require "test_helper"

describe "Planner::Series occurrences" do
  let(:user) { users(:member) }
  let(:october) { Date.new(2026, 10, 1)..Date.new(2026, 10, 31) }

  def series(**attrs)
    Planner::Series.create!({user:, title: "Gym", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=WEEKLY;BYDAY=MO",
                             start_time: "18:00", duration_minutes: 60, tracks_done: 1}.merge(attrs))
  end

  def dates(series, range = october) = series.dates(range).map(&:to_s)

  describe "#dates" do
    it "gives the dates the rule produces inside the range" do
      _(dates(series)).must_equal %w[2026-10-05 2026-10-12 2026-10-19 2026-10-26]
      _(dates(series, Date.new(2026, 10, 13)..Date.new(2026, 10, 19))).must_equal %w[2026-10-19]
    end

    it "is clipped to the visible span" do
      _(dates(series(from_on: Date.new(2026, 10, 12), ends_on: Date.new(2026, 10, 20)))).must_equal %w[2026-10-12 2026-10-19]
    end

    it "leaves out an excluded date" do
      gym = series
      gym.exclusions.create!(user_id: user.id, excluded_on: Date.new(2026, 10, 12))
      _(dates(gym)).must_equal %w[2026-10-05 2026-10-19 2026-10-26]
    end

    it "leaves out a date that has a row, whatever its state, and a row that moved away" do
      gym = series
      gym.build_occurrence(Date.new(2026, 10, 12)).save!
      moved = gym.build_occurrence(Date.new(2026, 10, 19)).tap(&:save!)
      moved.update!(day: Date.new(2026, 10, 21))
      gym.build_occurrence(Date.new(2026, 10, 26)).tap(&:save!).trash
      _(dates(gym)).must_equal %w[2026-10-05]
    end

    it "is empty when the rule has nothing in the range" do
      _(dates(series(rrule: "FREQ=MONTHLY;BYMONTHDAY=31", starts_on: Date.new(2026, 1, 31)), Date.new(2026, 4, 1)..Date.new(2026, 4, 30))).must_equal []
    end
  end

  describe "#build_occurrence" do
    it "is an unsaved event with the template, the day and the times of that day" do
      event = series(notes: "Bring a towel", priority: :high).build_occurrence(Date.new(2026, 10, 12))
      _(event).must_be :new_record?
      _(event).must_be :occurrence?
      _([event.title, event.notes, event.priority, event.tracks_done, event.day, event.occurrence_on]).must_equal ["Gym", "Bring a towel", "high", 1, Date.new(2026, 10, 12), Date.new(2026, 10, 12)]
      _([event.start_time, event.end_time, event.time_zone]).must_equal ["18:00", "19:00", "Europe/Rome"]
      _(event.starts_at).must_equal Time.utc(2026, 10, 12, 16)
    end

    it "is not saved by the series being saved" do
      gym = series
      gym.build_occurrence(Date.new(2026, 10, 12))
      assert_no_difference "Planner::Event.count" do
        gym.update!(title: "Gym 2")
      end
    end

    it "is all-day when the series has no start time" do
      event = series(start_time: nil, duration_minutes: nil).build_occurrence(Date.new(2026, 10, 12))
      _([event.starts_at, event.ends_at, event.time_zone]).must_equal [nil, nil, nil]
    end

    it "keeps the wall-clock time on the spring-forward day, moving a time that does not exist forward" do
      event = series(start_time: "02:30", duration_minutes: 30, rrule: "FREQ=WEEKLY;BYDAY=SU", starts_on: Date.new(2026, 3, 15)).build_occurrence(Date.new(2026, 3, 29))
      _(event.start_time).must_equal "03:30"
      _(event).must_be :valid?
    end
  end

  describe "#occurrence" do
    it "is the row when there is one, the built event when the rule gives the date, nil otherwise" do
      gym = series
      _(gym.occurrence(Date.new(2026, 10, 12))).must_be :new_record?
      row = gym.materialize(Date.new(2026, 10, 12))
      _(gym.occurrence(Date.new(2026, 10, 12))).must_equal row
      _(gym.occurrence(Date.new(2026, 10, 13))).must_be_nil
      _(gym.occurrence(Date.new(2026, 10, 5) - 7)).must_be_nil
    end

    it "is nil for an excluded date and the row for a trashed one" do
      gym = series
      gym.exclusions.create!(user_id: user.id, excluded_on: Date.new(2026, 10, 12))
      _(gym.occurrence(Date.new(2026, 10, 12))).must_be_nil
      gym.materialize(Date.new(2026, 10, 19)).trash
      _(gym.occurrence(Date.new(2026, 10, 19))).must_be :persisted?
    end
  end

  describe "#materialize" do
    it "saves the occurrence once, with the times of its day" do
      gym = series
      row = gym.materialize(Date.new(2026, 10, 12))
      _(row).must_be :persisted?
      _(gym.materialize(Date.new(2026, 10, 12))).must_equal row
      _(gym.events.count).must_equal 1
      _([row.series_id, row.occurrence_on, row.starts_at]).must_equal [gym.id, Date.new(2026, 10, 12), Time.utc(2026, 10, 12, 16)]
    end

    it "answers with the row that won when it lost a race" do
      gym = series
      stale = gym.build_occurrence(Date.new(2026, 10, 12))
      winner = gym.materialize(Date.new(2026, 10, 12))
      gym.define_singleton_method(:occurrence) { |_date| stale }
      _(gym.materialize(Date.new(2026, 10, 12))).must_equal winner
      _(gym.events.count).must_equal 1
    end

    it "refuses a date the rule does not give" do
      _(-> { series.materialize(Date.new(2026, 10, 13)) }).must_raise ActiveRecord::RecordNotFound
    end
  end
end
