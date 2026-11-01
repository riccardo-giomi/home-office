require "test_helper"
require_relative "shared_paged_agenda_list"

class Planner::MissedEventsControllerTest < ActionDispatch::IntegrationTest
  include SharedPagedAgendaList

  def list_path(**params) = planner_missed_events_path(**params)

  def page_title = "Missed events"

  def empty_text = "Nothing was missed."

  def late_item(day:, title:) = Planner::Event.create!(user: admin, title:, day:, tracks_done: 1)

  def badge_text(count) = "#{count} missed events"

  def clear_items = nil

  describe "what is missed" do
    before { sign_in_as admin }

    def titles = css_select("main li a").map(&:text)

    it "has the tracked events of days gone by that are not done, and nothing else" do
      late_item(day: Date.new(2026, 10, 1), title: "Pay the bill")
      Planner::Event.create!(user: admin, title: "Not tracked", day: Date.new(2026, 10, 1))
      Planner::Event.create!(user: admin, title: "Done one", day: Date.new(2026, 10, 1), tracks_done: 1, done_at: Time.current)
      Planner::Event.create!(user: admin, title: "Today", day: Date.new(2026, 10, 9), tracks_done: 1)
      Planner::Event.create!(user: admin, title: "Tomorrow", day: Date.new(2026, 10, 10), tracks_done: 1)
      Planner::Event.create!(user: admin, title: "Dropped", day: Date.new(2026, 10, 1), tracks_done: 1).change_state("abandoned")
      Planner::Event.create!(user: admin, title: "Called off", day: Date.new(2026, 10, 1), tracks_done: 1).change_state("cancelled")
      Planner::Event.create!(user: admin, title: "In the trash", day: Date.new(2026, 10, 1), tracks_done: 1).trash
      Planner::Event.create!(user: users(:other_admin), title: "Someone else's", day: Date.new(2026, 10, 1), tracks_done: 1)
      Planner::Task.create!(user: admin, title: "A task", day: Date.new(2026, 10, 1))
      get list_path
      assert_equal ["Pay the bill"], titles
    end

    it "has the past occurrences of a series, and catches up by itself even when the catch-up is off" do
      use_catch_up "off"
      Planner::Series.create!(user: admin, title: "Gym", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=DAILY", tracks_done: 1)
      Planner::Series.create!(user: admin, title: "Walk", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=DAILY")
      get list_path
      assert_equal 4, titles.count("Gym")
      assert_equal 0, titles.count("Walk")
    end

    it "leaves out the occurrence of a deleted date and of a trashed series" do
      use_catch_up "off"
      gym = Planner::Series.create!(user: admin, title: "Gym", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=DAILY", tracks_done: 1)
      gym.exclusions.create!(user_id: admin.id, excluded_on: Date.new(2026, 10, 6))
      Planner::Series.create!(user: admin, title: "Old", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=DAILY", tracks_done: 1, deleted_at: Time.current)
      get list_path
      assert_equal 3, titles.count("Gym")
      assert_equal 0, titles.count("Old")
    end

    it "no longer lists an event once it is ticked" do
      event = late_item(day: Date.new(2026, 10, 1), title: "Pay the bill")
      patch planner_item_completion_path(event), params: {done: "1"}
      get list_path
      assert_select "main a", text: "Pay the bill", count: 0
    end
  end

  describe "the Calendar and the Agenda" do
    before { sign_in_as admin }

    [:planner_calendar_path, :planner_agenda_path].each do |page|
      it "have a button to the list with the count (#{page})" do
        late_item(day: Date.new(2026, 10, 1), title: "Pay the bill")
        get public_send(page)
        assert_select "main a[href='#{list_path}']", text: /Missed events/ do
          assert_select "span.sr-only", text: "1 missed event"
        end
      end
    end
  end
end
