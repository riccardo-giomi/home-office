require "test_helper"

# The pages that "Show in Calendar" and similar links open mark the record named
# by `at` in the address.
class Planner::RevealTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }

  before do
    admin.update!(time_zone: "Europe/Rome", time_format: "24h", locale: "en")
    travel_to Time.utc(2026, 10, 9, 12)
    sign_in_as admin
  end

  def revealed = css_select("main [data-controller~='scroll-into-view']")

  it "marks the event on the day of the calendar" do
    get planner_calendar_path(view: "day", date: "2026-10-07", at: planner_items(:dentist).id)
    assert_equal 1, revealed.size
    assert_equal "Dentist", revealed.first.css("a").first.text.strip
  end

  it "marks the task on the day of the schedule" do
    get planner_schedule_path(view: "day", date: "2026-10-07", at: planner_items(:pay_rent_task).id)
    assert_equal ["Pay the rent"], revealed.map { |entry| entry.css("a").first.text.strip }
  end

  it "marks the todo in the list" do
    get planner_todos_path(at: planner_items(:water_plants_todo).id)
    assert_equal ["Water the plants"], revealed.map { |entry| entry.css("a").first.text.strip }
  end

  it "marks nothing when the address names no record of the page, or none" do
    get planner_calendar_path(view: "day", date: "2026-10-07")
    assert_empty revealed
    get planner_calendar_path(view: "day", date: "2026-10-07", at: "0")
    assert_empty revealed
    get planner_calendar_path(view: "day", date: "2026-10-07", at: "junk")
    assert_response :success
    assert_empty revealed
  end

  describe "an occurrence of a series" do
    let(:series) { Planner::Series.create!(user: admin, title: "Gym", starts_on: Date.new(2026, 10, 9), time_zone: "Europe/Rome", rrule: "FREQ=DAILY") }

    it "marks an unsaved occurrence, named by its series and date" do
      get planner_calendar_path(view: "day", date: "2026-10-09", at: "series-#{series.id}-2026-10-09")
      assert_equal ["Gym"], revealed.map { |entry| entry.css("a").first.text.strip }
    end

    it "marks nothing for the series and another date, or for an empty name" do
      get planner_calendar_path(view: "day", date: "2026-10-09", at: "series-#{series.id}-2026-10-10")
      assert_empty revealed
      get planner_calendar_path(view: "day", date: "2026-10-09", at: "")
      assert_empty revealed
    end

    it "marks the saved occurrence by its id, and by the name it had before it was saved" do
      saved = series.materialize(Date.new(2026, 10, 9))
      get planner_calendar_path(view: "day", date: "2026-10-09", at: saved.id)
      assert_equal 1, revealed.size
      get planner_calendar_path(view: "day", date: "2026-10-09", at: "series-#{series.id}-2026-10-09")
      assert_equal 1, revealed.size
    end
  end
end
