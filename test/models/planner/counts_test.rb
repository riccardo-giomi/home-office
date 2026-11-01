require "test_helper"

describe Planner::Counts do
  let(:user) { users(:admin) }
  # 22:00 on Wed 7 Oct in New York is already Thu 8 Oct in UTC
  let(:now) { Time.utc(2026, 10, 8, 2) }

  before do
    Planner::Item.delete_all
    Planner::Series.delete_all
    Current.reset
    travel_to now
    Time.zone = "America/New_York"
  end

  after { Time.zone = "UTC" }

  def today = Date.current

  def counts
    Planner::Counts.reset
    Planner::Counts.for(user)
  end

  def event(title = "E", day: today, owner: user, **attrs) = Planner::Event.create!({user: owner, title:, day:}.merge(attrs))

  def task(title = "T", day: today, owner: user, **attrs) = Planner::Task.create!({user: owner, title:, day:}.merge(attrs))

  describe "the lists" do
    it "counts the forgotten tasks, with today taken from the user's zone, not UTC" do
      task("Yesterday", day: today - 1)
      task("Today")
      _(counts.forgotten).must_equal 1
      _(counts.forgotten).must_equal Planner::Task.owned_by(user).forgotten(today).count
    end

    it "counts the missed events" do
      event("Missed", day: today - 2, tracks_done: 1)
      _(counts.missed).must_equal 1
      _(counts.missed).must_equal Planner::Event.owned_by(user).missed(today).count
    end

    it "counts the important events" do
      event("Urgent", priority: "urgent")
      _(counts.important).must_equal 1
      _(counts.important).must_equal Planner::ImportantEvents.new(user, today:).count
    end
  end

  describe "sharing" do
    it "is the same object twice in a request, a new one after a reset" do
      first = Planner::Counts.for(user)
      _(Planner::Counts.for(user)).must_be_same_as first
      Planner::Counts.reset
      _(Planner::Counts.for(user)).wont_be_same_as first
    end

    it "asks the database once for a number asked twice" do
      c = counts
      task("Forgotten", day: today - 3)
      queries = count_queries { 2.times { c.forgotten } }
      _(queries).must_equal 1
    end
  end

  def count_queries(&)
    count = 0
    callback = ->(*, payload) { count += 1 unless payload[:name] == "SCHEMA" || payload[:cached] }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &)
    count
  end
end
