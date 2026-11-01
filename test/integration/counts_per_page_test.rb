require "test_helper"

class CountsPerPageTest < ActionDispatch::IntegrationTest
  it "works out Important once for a page that shows it in the sidebar and in the tab" do
    user = users(:member)
    Planner::Series.create!(user:, title: "Urgent daily", priority: "urgent", starts_on: Date.current, time_zone: "UTC", rrule: "FREQ=DAILY")
    sign_in_as user
    expansions = 0
    callback = ->(*, payload) { expansions += 1 if payload[:sql].match?(/FROM "planner_series"/) && payload[:sql].include?("priority") }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record") { get planner_important_events_path }
    assert_response :success
    # One query for the sidebar badge and one for the list itself. The tab
    # reuses the number of the badge.
    assert_operator expansions, :<=, 2
  end
end
