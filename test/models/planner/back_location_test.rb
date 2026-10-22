require "test_helper"

describe Planner::BackLocation do
  it "accepts the calendar and the agenda, with a view and a date" do
    ["/planner/calendar", "/planner/agenda", "/planner/calendar?view=week&date=2026-10-07", "/planner/agenda?view=day&date=2026-10-07"].each do |path|
      location = Planner::BackLocation.parse(path)
      _(location&.path).must_equal path, path
    end
  end

  it "accepts the schedule too" do
    ["/planner/schedule?view=week&date=2026-10-07"].each do |path|
      _(Planner::BackLocation.parse(path)&.path).must_equal path
    end
    _(Planner::BackLocation.parse("/planner/schedule").page).must_equal :schedule
  end

  it "does not accept the item pages themselves" do
    assert_nil Planner::BackLocation.parse("/planner/tasks/1")
  end

  it "knows which page it is, to name the way back" do
    _(Planner::BackLocation.parse("/planner/agenda?view=day").page).must_equal :agenda
    _(Planner::BackLocation.parse("/planner/calendar").page).must_equal :calendar
  end

  it "accepts nothing else: other pages, other sites, tricks" do
    ["https://evil.example/", "//evil.example", "/admin/users", "/planner/calendar/../../session", "javascript:alert(1)",
      "/planner/calendar?x=<b>", "/planner/calendarx", "/planner/calendar?view=week\nSet-Cookie: x=1", "", nil, ["/planner/calendar"], {a: 1}, "http://localhost/planner/calendar"].each do |value|
      assert_nil Planner::BackLocation.parse(value), value.inspect
    end
  end
end
