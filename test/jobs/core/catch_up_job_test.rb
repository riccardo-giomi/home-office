require "test_helper"

describe Core::CatchUpJob do
  before { travel_to Time.utc(2026, 3, 10, 18, 40) }

  def series_for(user, zone: "Europe/Rome")
    user.update_columns(time_zone: zone)
    Planner::Series.create!(user:, title: "Gym", starts_on: Date.new(2026, 3, 5), time_zone: zone, rrule: "FREQ=DAILY",
      start_time: "18:00", duration_minutes: 60, tracks_done: 1, priority: "high")
  end

  it "makes the past real for every active user and leaves a deactivated user alone" do
    mine, theirs, gone = series_for(users(:member)), series_for(users(:admin)), series_for(users(:retired))
    Core::CatchUpJob.perform_now
    _(mine.reload.materialized_through).must_equal Date.new(2026, 3, 9)
    _(theirs.reload.materialized_through).must_equal Date.new(2026, 3, 9)
    _(gone.reload.materialized_through).must_be_nil
  end

  it "takes today from the time zone of each user" do
    kolkata = series_for(users(:member), zone: "Asia/Kolkata") # 00:10 on the 11th there
    auckland = series_for(users(:admin), zone: "Pacific/Auckland") # the 11th, 07:40
    chicago = series_for(users(:other_admin), zone: "America/Chicago") # the 10th, 13:40
    Core::CatchUpJob.perform_now
    _(kolkata.reload.materialized_through).must_equal Date.new(2026, 3, 10)
    _(auckland.reload.materialized_through).must_equal Date.new(2026, 3, 10)
    _(chicago.reload.materialized_through).must_equal Date.new(2026, 3, 9)
  end

  it "does nothing the second time" do
    series_for(users(:member))
    Core::CatchUpJob.perform_now
    assert_no_difference "Planner::Event.count" do
      Core::CatchUpJob.perform_now
    end
  end

  it "goes on with the other users when one fails, and reports the failure" do
    series_for(users(:member))
    ok = series_for(users(:admin))
    failing = users(:member)
    raising = ->(user, today:) { (user == failing) ? raise("boom") : Planner::Series.catch_up(user, today:) }
    reported = []
    subscriber = Struct.new(:reports) { def report(error, **) = reports << error.message }.new(reported)
    Rails.error.subscribe(subscriber)
    original = Planner::CatchUp.method(:run)
    Planner::CatchUp.define_singleton_method(:run) { |user, today:| raising.call(user, today:) }
    Core::CatchUpJob.perform_now
    _(ok.reload.materialized_through).must_equal Date.new(2026, 3, 9)
    _(reported).must_include "boom"
  ensure
    Planner::CatchUp.define_singleton_method(:run, original)
    Rails.error.unsubscribe(subscriber)
  end

  it "does not stop on a stored time zone that is not valid" do
    user = users(:member)
    mine = series_for(user)
    user.update_columns(time_zone: "Mars/Olympus")
    Core::CatchUpJob.perform_now
    _(mine.reload.materialized_through).must_equal Date.new(2026, 3, 9)
  end
end
