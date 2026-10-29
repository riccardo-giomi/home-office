require "test_helper"

describe Planner::Occurrences do
  include QueryCounting

  let(:user) { users(:member) }
  let(:week) { Date.new(2026, 10, 5)..Date.new(2026, 10, 11) }

  def series(user: self.user, **attrs)
    Planner::Series.create!({user:, title: "Gym", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=DAILY", start_time: "18:00", duration_minutes: 60}.merge(attrs))
  end

  it "gives the rows and the ghosts of the range, earliest first" do
    series(rrule: "FREQ=WEEKLY;BYDAY=MO,WE")
    Planner::Event.create!(user:, title: "Dentist", day: Date.new(2026, 10, 6))
    found = Planner::Occurrences.for(user, week)
    _(found.map { |event| [event.day.to_s, event.title, event.persisted?] }).must_equal [["2026-10-05", "Gym", false], ["2026-10-06", "Dentist", true], ["2026-10-07", "Gym", false]]
  end

  it "shows a row instead of its ghost, once, on the day it moved to" do
    gym = series
    row = gym.materialize(Date.new(2026, 10, 6))
    row.update!(day: Date.new(2026, 10, 9))
    found = Planner::Occurrences.for(user, week).select { |event| event.title == "Gym" }
    _(found.count { |event| event.day == Date.new(2026, 10, 9) }).must_equal 2 # the moved row and the 9th's own ghost
    _(found.count { |event| event.day == Date.new(2026, 10, 6) }).must_equal 0
    _(found.count).must_equal 7
  end

  it "does not show a trashed row, nor its ghost" do
    gym = series
    gym.materialize(Date.new(2026, 10, 6)).trash
    _(Planner::Occurrences.for(user, week).select { |event| event.title == "Gym" }.map { |event| event.day.to_s }).wont_include "2026-10-06"
  end

  it "does not show the ghosts of a trashed series, of another user, or outside the span" do
    series(title: "Trashed").trash
    series(user: users(:admin), title: "Theirs")
    series(title: "Over", ends_on: Date.new(2026, 10, 4), starts_on: Date.new(2026, 10, 1))
    _(Planner::Occurrences.for(user, week)).must_be :empty?
  end

  it "asks a fixed number of questions however many series there are" do
    series
    few = selects { Planner::Occurrences.for(user, week) }.size
    3.times { |n| series(title: "More #{n}") }
    _(selects { Planner::Occurrences.for(user, week) }.size).must_equal few
  end
end
