require "test_helper"
require_relative "shared_item_pages"

class Planner::EventsControllerTest < ActionDispatch::IntegrationTest
  include SharedItemPages

  let(:item_class) { Planner::Event }
  let(:kind) { "event" }
  let(:sample) { planner_items(:dentist) }
  let(:all_day_sample) { planner_items(:holiday) }
  let(:foreign) { planner_items(:other_users_event) }

  def default_back(event) = planner_calendar_path(date: event.day.iso8601)

  describe "what only events have" do
    before { sign_in_as admin }

    it "can switch the done checkbox on when created, and never sets done_at itself" do
      post planner_events_path, params: {planner_event: {title: "Rent", day: "2026-10-09", tracks_done: "1", done_at: "2026-01-01"}}
      event = Planner::Event.order(:id).last
      assert_equal [1, nil], [event.tracks_done, event.done_at]
    end

    it "offers the tracks_done field in the form" do
      get new_planner_event_path
      assert_select "input[type=checkbox][name='planner_event[tracks_done]']"
    end

    it "says when a done event was done with a time element, not with its markup as text" do
      get planner_event_path(planner_items(:rent_paid))
      assert_select "dd time[datetime^='2026-10-01']"
      assert_select "dd", text: /<time/, count: 0
      assert_select "dd", text: /Done on 10\/01\/2026/
    end

    it "offers the done checkbox only to events that track it" do
      get planner_event_path(planner_items(:rent_open))
      assert_select "input[type=checkbox][aria-label='Done: Rent November']", 1
      get planner_event_path(planner_items(:holiday))
      assert_select "input[type=checkbox]", 0
    end

    it "names the calendar as the way back" do
      get planner_event_path(planner_items(:dentist))
      assert_select "a", text: "Back to calendar"
    end
  end
end
