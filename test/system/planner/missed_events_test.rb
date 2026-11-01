require "application_system_test_case"
require_relative "paged_agenda_list_examples"

class Planner::MissedEventsSystemTest < ApplicationSystemTestCase
  include PagedAgendaListExamples

  def list_path(**params) = planner_missed_events_path(**params)

  def controller_kind = "missed_events"

  def item_kind = "event"

  def late_item(title, days_ago) = Planner::Event.create!(user: admin, title:, day: Date.current - days_ago, tracks_done: 1)

  def clear_items = nil

  def abandon_label = I18n.t("planner.kinds.event.abandon")

  it "is reached from the Calendar and the Agenda, which count what was missed" do
    late_item("Rent", 2)
    sign_in_through_form admin
    [planner_calendar_path, planner_agenda_path].each do |page|
      visit page
      within("main") { click_link(href: list_path) }
      assert_selector "h1", text: "Missed events"
      assert_selector "main li a", text: "Rent"
    end
  end

  it "lists the past days of a series that was never opened, as soon as the page is opened" do
    use_catch_up "off"
    Planner::Series.create!(user: admin, title: "Gym", starts_on: Date.current - 3, time_zone: "UTC", rrule: "FREQ=DAILY", tracks_done: 1)
    sign_in_through_form admin
    visit list_path
    assert_selector "main li a", text: "Gym", count: 3
  end
end
