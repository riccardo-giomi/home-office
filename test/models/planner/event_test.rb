require "test_helper"

describe Planner::Event do
  let(:user) { users(:member) }

  def build(**attrs) = Planner::Event.new({user:, title: "Dentist", day: Date.new(2026, 10, 7)}.merge(attrs))

  describe "all-day events" do
    it "needs only a title and a day" do
      event = build
      _(event.save).must_equal true
      _([event.starts_at, event.ends_at, event.time_zone]).must_equal [nil, nil, nil]
      _(event.state).must_equal "active"
    end

    it "turns a timed event into an all-day one when both times are cleared" do
      event = planner_items(:dentist)
      event.update!(start_time: "", end_time: "")
      _([event.starts_at, event.ends_at, event.time_zone]).must_equal [nil, nil, nil]
    end
  end

  describe "title and day" do
    it "strips the title and rejects a blank or too long one" do
      _(build(title: "  Dentist  ").tap(&:save!).title).must_equal "Dentist"
      _(build(title: "   ").tap(&:valid?).errors[:title]).wont_be_empty
      _(build(title: "a" * 256).tap(&:valid?).errors[:title]).wont_be_empty
    end

    it "rejects a day that is not a date" do
      _(build(day: "2026-02-30").tap(&:valid?).errors[:day]).wont_be_empty
      _(build(day: nil).tap(&:valid?).errors[:day]).wont_be_empty
    end
  end

  describe "timed events" do
    it "stores UTC instants and the zone of the request" do
      Time.use_zone("Europe/Rome") do
        event = build(start_time: "09:30", end_time: "10:15")
        event.save!
        _(event.starts_at.utc.iso8601).must_equal "2026-10-07T07:30:00Z"
        _(event.ends_at.utc.iso8601).must_equal "2026-10-07T08:15:00Z"
        _(event.time_zone).must_equal "Europe/Rome"
        _([event.start_time, event.end_time]).must_equal %w[09:30 10:15]
      end
    end

    it "fills a blank end 30 minutes after the start" do
      Time.use_zone("Europe/Rome") do
        event = build(start_time: "09:30", end_time: "").tap(&:save!)
        _(event.end_time).must_equal "10:00"
      end
    end

    it "keeps the end typed by the user when it differs from the default" do
      Time.use_zone("UTC") { _(build(start_time: "09:00", end_time: "09:10").tap(&:save!).end_time).must_equal "09:10" }
    end

    it "rejects an end that is not after the start" do
      Time.use_zone("UTC") do
        _(build(start_time: "09:00", end_time: "09:00").tap(&:valid?).errors[:end_time]).wont_be_empty
        _(build(start_time: "09:00", end_time: "08:00").tap(&:valid?).errors[:end_time]).wont_be_empty
      end
    end

    it "clamps the default end to the end of the day instead of failing" do
      Time.use_zone("UTC") do
        event = build(start_time: "23:45", end_time: "").tap(&:save!)
        _(event.ends_at.utc.iso8601).must_equal "2026-10-07T23:59:59Z"
        _(event.end_time).must_equal "23:59"
        _(build(start_time: "23:59", end_time: "").tap(&:save!).ends_at.utc.iso8601).must_equal "2026-10-07T23:59:59Z"
      end
    end

    it "still rejects an end the user typed on the next day's side of the start" do
      Time.use_zone("UTC") do
        event = build(start_time: "23:45", end_time: "23:30")
        _(event.valid?).must_equal false
        _(event.errors[:end_time]).wont_be_empty
      end
    end

    it "asks for a start when only an end is given" do
      Time.use_zone("UTC") { _(build(start_time: "", end_time: "10:00").tap(&:valid?).errors[:start_time]).wont_be_empty }
    end

    it "rejects malformed times without raising" do
      Time.use_zone("UTC") do
        ["9:5", "24:00", "ab", "09:60"].each do |bad|
          _(build(start_time: bad, end_time: "").tap(&:valid?).errors[:start_time]).wont_be_empty
        end
        _(build(start_time: "09:00", end_time: "nope").tap(&:valid?).errors[:end_time]).wont_be_empty
      end
    end

    it "keeps the stored zone when edited in another zone" do
      event = planner_items(:dentist)
      Time.use_zone("Asia/Tokyo") { event.update!(start_time: "10:00", end_time: "11:00") }
      _(event.time_zone).must_equal "Europe/Rome"
      _(event.starts_at.utc.iso8601).must_equal "2026-10-07T08:00:00Z"
    end

    it "takes the current zone when an all-day event becomes timed" do
      event = planner_items(:holiday)
      Time.use_zone("America/New_York") { event.update!(start_time: "09:00", end_time: "10:00") }
      _(event.time_zone).must_equal "America/New_York"
    end

    it "moves the instants with the day when only the day changes" do
      event = planner_items(:dentist)
      event.update!(day: Date.new(2026, 10, 9))
      _(event.start_time).must_equal "09:30"
      _(event.starts_at.in_time_zone("Europe/Rome").to_date).must_equal Date.new(2026, 10, 9)
    end

    it "keeps the typed day for someone far ahead of UTC" do
      Time.use_zone("Pacific/Auckland") do
        event = build(start_time: "00:30", end_time: "01:00").tap(&:save!)
        _(event.day).must_equal Date.new(2026, 10, 7)
        _(event.starts_at.in_time_zone("Pacific/Auckland").to_date).must_equal Date.new(2026, 10, 7)
        _(event.reload.start_time).must_equal "00:30"
      end
    end

    it "does not raise on a time inside the spring-forward gap or the repeated fall hour" do
      Time.use_zone("Europe/Rome") do
        gap = build(day: Date.new(2026, 3, 29), start_time: "02:30", end_time: "").tap(&:save!)
        _(gap.starts_at.in_time_zone("Europe/Rome").to_date).must_equal Date.new(2026, 3, 29)
        repeated = build(day: Date.new(2026, 10, 25), start_time: "02:30", end_time: "").tap(&:save!)
        _(repeated.starts_at.in_time_zone("Europe/Rome").to_date).must_equal Date.new(2026, 10, 25)
      end
    end

    it "checks that day is the local date of starts_at when instants are assigned directly" do
      event = build(starts_at: Time.utc(2026, 10, 6, 23, 30), ends_at: Time.utc(2026, 10, 7, 0, 0), time_zone: "UTC")
      _(event.valid?).must_equal false
      _(event.errors[:day]).wont_be_empty
    end

    it "needs a known zone when there are instants" do
      event = build(starts_at: Time.utc(2026, 10, 7, 9), ends_at: Time.utc(2026, 10, 7, 10), time_zone: "Mars/Olympus")
      _(event.valid?).must_equal false
      _(event.errors[:time_zone]).wont_be_empty
    end
  end

  describe "tracks_done" do
    it "is 0 or 1, never another number (the database check is not the first line of defense)" do
      [2, -1, 5].each do |value|
        event = Planner::Event.new(user:, title: "Rent", day: Date.new(2026, 10, 7), tracks_done: value)
        _(event).wont_be :valid?
        _(event.errors[:tracks_done]).wont_be :empty?
      end
    end
  end

  describe "done" do
    it "is set and cleared only on events that track it" do
      freeze_time do
        event = planner_items(:rent_open)
        event.mark_done(true)
        _(event.done_at).must_equal Time.current
        _(event.done?).must_equal true
        event.mark_done(false)
        _(event.done_at).must_be_nil

        other = planner_items(:holiday)
        other.mark_done(true)
        _(other.done_at).must_be_nil
      end
    end

    it "forgets being done when tracking is turned off" do
      event = planner_items(:rent_paid)
      event.update!(tracks_done: 0)
      _(event.reload.done_at).must_be_nil
    end
  end

  describe ".owned_by" do
    it "returns only the user's events" do
      titles = Planner::Event.owned_by(users(:other_admin)).kept.pluck(:title)
      _(titles).must_equal ["Someone else's secret"]
    end
  end
end
