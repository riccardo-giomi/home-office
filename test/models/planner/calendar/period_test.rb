require "test_helper"

describe Planner::Calendar::Period do
  let(:today) { Date.new(2026, 10, 6) }

  def period(view: nil, date: nil, first_weekday: 0) = Planner::Calendar::Period.new(view:, date:, first_weekday:, today:)

  it "defaults to the month of today" do
    _(period.view).must_equal :month
    _(period.date).must_equal today
    _(period.range).must_equal Date.new(2026, 10, 1)..Date.new(2026, 10, 31)
  end

  it "falls back to today and the month for junk or out-of-bounds input" do
    ["junk", "0000-01-01", "2300-01-01", "2026-02-30", ""].each do |date|
      _(period(date:).date).must_equal today
    end
    _(period(view: "banana").view).must_equal :month
    _(period(date: "2026-03-15").date).must_equal Date.new(2026, 3, 15)
  end

  it "draws the month in whole weeks starting on the first weekday" do
    _(period(first_weekday: 0).grid_range).must_equal Date.new(2026, 9, 27)..Date.new(2026, 10, 31)
    _(period(first_weekday: 1).grid_range).must_equal Date.new(2026, 9, 28)..Date.new(2026, 11, 1)
  end

  it "needs only four rows for a February of 28 days starting on the first weekday" do
    feb = period(date: "2027-02-10", first_weekday: 1)
    _(feb.grid_range.count).must_equal 28
  end

  it "takes the week from the first weekday" do
    {0 => "2026-10-04", 1 => "2026-10-05", 6 => "2026-10-03"}.each do |first_weekday, first|
      week = period(view: "week", first_weekday:)
      _(week.range.first).must_equal Date.iso8601(first)
      _(week.range.count).must_equal 7
      _(week.days_of_week.first).must_equal Date.iso8601(first)
      _(week.grid_range).must_equal week.range
    end
  end

  it "covers exactly one date in the day view, whatever the first weekday" do
    day = period(view: "day", date: "2026-10-20", first_weekday: 1)
    _(day.view).must_equal :day
    _(day.range).must_equal Date.new(2026, 10, 20)..Date.new(2026, 10, 20)
    _(day.grid_range).must_equal day.range
    _(day.days_of_week.size).must_equal 7
  end

  it "no longer knows an agenda view (that is a page of its own)" do
    _(period(view: "agenda").view).must_equal :month
  end

  it "moves by a month or a week, across a year and onto shorter months" do
    _(period(date: "2026-12-15").next.date).must_equal Date.new(2027, 1, 15)
    _(period(date: "2026-01-31").next.date).must_equal Date.new(2026, 2, 28)
    _(period(view: "week", date: "2026-12-29").next.date).must_equal Date.new(2027, 1, 5)
    _(period(view: "day", date: "2026-03-01").previous.date).must_equal Date.new(2026, 2, 28)
    _(period(view: "day", date: "2026-12-31").next.date).must_equal Date.new(2027, 1, 1)
    _(period(view: "week", date: "2026-01-02").previous.view).must_equal :week
  end

  it "switches view keeping the date and round-trips through its params" do
    week = period(date: "2026-10-20").with_view(:week)
    _(week.view).must_equal :week
    _(week.to_params).must_equal({view: "week", date: "2026-10-20"})
    again = period(view: week.to_params[:view], date: week.to_params[:date])
    _(again.date).must_equal week.date
  end

  describe "with its own list of views (the schedule)" do
    def schedule_period(view: nil, date: nil) = Planner::Calendar::Period.new(view:, date:, first_weekday: 0, today:, views: %i[day week], default: :day)

    it "knows its views and defaults to the first" do
      _(schedule_period.views).must_equal %i[day week]
      _(schedule_period.view).must_equal :day
      _(schedule_period(view: "week").view).must_equal :week
    end

    it "falls back to the default for a view it does not offer, or junk" do
      ["month", "banana", "", nil].each { |view| _(schedule_period(view:).view).must_equal :day, view.inspect }
    end

    it "keeps its views when it moves or changes view" do
      _(schedule_period(view: "week").next.views).must_equal %i[day week]
      _(schedule_period.previous.view).must_equal :day
      _(schedule_period.with_view(:week).views).must_equal %i[day week]
      _(schedule_period.with_view(:month).view).must_equal :day
    end
  end

  it "is the month, week and day calendar unless told otherwise" do
    _(period.views).must_equal %i[month week day]
    _(period(view: "week").next.views).must_equal %i[month week day]
  end
end
