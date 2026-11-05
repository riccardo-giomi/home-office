require "test_helper"

class CatchUpJobModeTest < ActionDispatch::IntegrationTest
  before { travel_to Time.utc(2026, 3, 10, 18, 40) }

  it "makes the past real through the job alone in job mode, and not through a request" do
    use_catch_up "job"
    users(:member).update_columns(time_zone: "Europe/Rome")
    mine = Planner::Series.create!(user: users(:member), title: "Gym", starts_on: Date.new(2026, 3, 5), time_zone: "Europe/Rome",
      rrule: "FREQ=DAILY", start_time: "18:00", duration_minutes: 60, tracks_done: 1, priority: "high")
    sign_in_as users(:member)
    get root_path
    assert_response :success
    assert_nil mine.reload.materialized_through
    Core::CatchUpJob.perform_now
    assert_equal Date.new(2026, 3, 9), mine.reload.materialized_through
  end
end
