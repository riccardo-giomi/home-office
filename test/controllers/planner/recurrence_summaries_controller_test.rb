require "test_helper"

class Planner::RecurrenceSummariesControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }

  before do
    admin.update!(time_zone: "Europe/Rome", locale: "en")
    sign_in_as admin
  end

  it "sends anonymous visitors to sign in" do
    sign_out
    get planner_recurrence_summary_path
    assert_redirected_to new_session_path
  end

  it "says the rule in words, as plain text" do
    get planner_recurrence_summary_path, params: {day: "2026-10-05", repeat: {frequency: "weekly", interval: "2", weekdays: ["MO", "WE"], ends: "until", until_on: "2026-12-03"}}
    assert_response :success
    assert_equal "text/plain", response.media_type
    assert_equal "Every 2 weeks on Mon, Wed, until 3 Dec 2026", response.body
  end

  it "follows the day for the parts that come from it" do
    get planner_recurrence_summary_path, params: {day: "2026-10-13", repeat: {frequency: "monthly", monthly: "weekday"}}
    assert_equal "Every month on the 2nd Tue", response.body
  end

  it "falls back to the weekday of the day when no weekday is ticked, and says so" do
    get planner_recurrence_summary_path, params: {day: "2026-10-05", repeat: {frequency: "weekly", weekdays: [""]}}
    assert_equal "Every week on Mon", response.body
  end

  it "speaks the language of the user" do
    admin.update!(locale: "it")
    get planner_recurrence_summary_path, params: {day: "2026-10-05", repeat: {frequency: "daily"}}
    assert_equal "Ogni giorno", response.body
  end

  it "says nothing when the event does not repeat or the rule is not complete yet" do
    [{frequency: "never"}, {frequency: "daily", interval: "0"}, {frequency: "daily", ends: "until"}].each do |repeat|
      get planner_recurrence_summary_path, params: {day: "2026-10-05", repeat:}
      assert_response :success
      assert_equal "", response.body, repeat.inspect
    end
  end

  it "says nothing, and does not fail, for a day it cannot read" do
    ["", "junk", "2026-02-30"].each do |day|
      get planner_recurrence_summary_path, params: {day:, repeat: {frequency: "daily"}}
      assert_response :success
      assert_equal "", response.body
    end
  end
end
