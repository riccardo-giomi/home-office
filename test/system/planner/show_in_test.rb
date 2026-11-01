require "application_system_test_case"

class Planner::ShowInSystemTest < ApplicationSystemTestCase
  let(:admin) { users(:admin) }

  before do
    admin.update!(time_zone: "UTC", time_format: "24h", locale: "en")
    sign_in_through_form admin
    page.current_window.resize_to(1400, 700)
  end

  # True when the whole entry is inside the visible part of the page. The page
  # scrolls right after it opens, so the test waits one second for this: a
  # scroll that comes later, when the highlight ends, does not count.
  def assert_in_view(title)
    entry = find("main a", text: title)
    page.document.synchronize(1) do
      on_screen = entry.evaluate_script("(function (element) { const box = element.getBoundingClientRect(); return box.top >= 0 && box.bottom <= window.innerHeight })(this)")
      raise Capybara::ExpectationNotMet, "#{title} is not on the screen" unless on_screen
    end
  end

  it "opens the day of the calendar with an evening event in view" do
    event = Planner::Event.create!(user: admin, title: "Evening class", day: Date.current, start_time: "18:00", end_time: "19:00")
    visit planner_event_path(event)
    click_link "Show in Calendar"
    assert_selector "h1", text: "Calendar"
    assert_in_view "Evening class"
  end

  it "opens the day of the calendar with an evening occurrence that was never saved in view" do
    series = Planner::Series.create!(user: admin, title: "Evening yoga", starts_on: Date.current, time_zone: "UTC", rrule: "FREQ=DAILY", start_time: "18:00", duration_minutes: 60)
    visit planner_series_occurrence_path(series, Date.current.iso8601)
    click_link "Show in Calendar"
    assert_selector "h1", text: "Calendar"
    assert_in_view "Evening yoga"
  end

  it "opens the day of the schedule with an evening task in view" do
    task = Planner::Task.create!(user: admin, title: "Evening call", day: Date.current, start_time: "18:00", end_time: "19:00")
    visit planner_task_path(task)
    click_link "Show in Schedule"
    assert_selector "h1", text: "Schedule"
    assert_in_view "Evening call"
  end

  it "opens the list of todos with a todo from the bottom of a long list in view" do
    Planner::Todo.where(user: admin).destroy_all
    30.times { |number| Planner::Todo.create!(user: admin, title: format("Todo %02d", number + 1)) }
    visit planner_todo_path(Planner::Todo.find_by!(user: admin, title: "Todo 30"))
    click_link "Show in Todos"
    assert_selector "h1", text: "Todos"
    assert_in_view "Todo 30"
  end
end
