require "test_helper"

describe Core::DaySlice do
  def slice(mode = nil, start_hour: 7, end_hour: 21) = Core::DaySlice.new(start_hour:, end_hour:, mode:)

  it "shows the day hours by default, the end hour included" do
    _(slice.mode).must_equal "day"
    _(slice.segments).must_equal [420...1320]
  end

  it "shows the hours before and after as two stretches" do
    _(slice("rest").segments).must_equal [0...420, 1320...1440]
  end

  it "drops the stretch that would be empty" do
    _(slice("rest", start_hour: 0).segments).must_equal [1320...1440]
    _(slice("rest", end_hour: 23).segments).must_equal [0...420]
  end

  it "has nothing else to show when the day hours are the whole day" do
    whole = slice("rest", start_hour: 0, end_hour: 23)
    _(whole.segments).must_equal []
    _(whole.modes).must_equal []
  end

  it "shows everything on request" do
    _(slice("all").segments).must_equal [0...1440]
  end

  it "reads one single hour" do
    _(slice(start_hour: 9, end_hour: 9).segments).must_equal [540...600]
  end

  it "falls back to the day hours for anything else" do
    ["junk", "", nil, "REST"].each { |mode| _(slice(mode).mode).must_equal "day" }
  end

  it "offers every mode, in order, unless they would all show the same" do
    _(slice.modes).must_equal %w[day rest all]
  end

  it "points from the day hours to the hours around them, and from those and from all back to the day hours" do
    _(slice.other).must_equal "rest"
    _(slice("rest").other).must_equal "day"
    _(slice("all").other).must_equal "rest"
  end
end
