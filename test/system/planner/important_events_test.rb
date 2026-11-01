require "application_system_test_case"

class Planner::ImportantEventsSystemTest < ApplicationSystemTestCase
  let(:admin) { users(:admin) }

  def urgent(title, days_ahead = 0) = Planner::Event.create!(user: admin, title:, day: Date.current + days_ahead, priority: "urgent")

  before { admin.update!(time_zone: "UTC", time_format: "24h", locale: "en") }

  %w[light dark].each do |theme|
    it "has no axe violations in the #{theme} theme, with events and without" do
      admin.update!(theme:)
      sign_in_through_form admin
      visit planner_important_events_path
      assert_text "Nothing important in the next 7 days."
      assert_accessible
      urgent("Deadline")
      Planner::Series.create!(user: admin, title: "Standup", priority: "urgent", starts_on: Date.current, time_zone: "UTC", rrule: "FREQ=DAILY")
      visit planner_important_events_path(horizon: "30d", minimum: "high")
      assert_text "Deadline"
      assert_accessible
      visit planner_agenda_path
      assert_selector "nav a", text: /Important/
      assert_accessible
    end
  end

  it "fits 320 px with a title of 255 unbroken characters" do
    urgent("W" * 255)
    sign_in_through_form admin
    small_screen do
      visit planner_important_events_path
      assert_selector "main li a"
      assert_fits_small_screen
    end
  end

  it "is the fourth tab of the agenda, and the filters are links that keep each other" do
    urgent("Deadline", 10)
    sign_in_through_form admin
    visit planner_agenda_path
    within("main") { click_link(href: planner_important_events_path) }
    assert_selector "h1", text: "Important"
    assert_no_selector "main li a", text: "Deadline"
    click_link "30 days"
    assert_selector "main li a", text: "Deadline"
    click_link "Urgent and high"
    assert_selector "nav[aria-label='Priority'] a[aria-current=true]", text: "Urgent and high"
    assert_includes current_url, "horizon=30d"
    assert_includes current_url, "minimum=high"
    assert_selector "nav[aria-label='Horizon'] a[aria-current=true]", text: "30 days"
  end

  it "ticks an event that tracks done, which then leaves the list, with focus on the heading" do
    Planner::Event.create!(user: admin, title: "Pay the tax", day: Date.current + 1, priority: "urgent", tracks_done: 1)
    sign_in_through_form admin
    visit planner_important_events_path
    find("input[aria-label='Done: Pay the tax']").click
    assert_no_selector "main li a", text: "Pay the tax"
    assert_selector "main h1:focus"
  end

  it "reaches the views of the agenda with the keyboard" do
    sign_in_through_form admin
    visit planner_important_events_path
    find("nav[aria-label='Agenda views'] a", text: "Week").send_keys(:enter)
    assert_selector "h1", text: "Agenda"
  end
end
