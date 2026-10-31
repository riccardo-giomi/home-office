require "test_helper"
require_relative "shared_item_pages"
require_relative "shared_timed_item_pages"

class Planner::EventsControllerTest < ActionDispatch::IntegrationTest
  include SharedItemPages
  include SharedTimedItemPages

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

  describe "repeating events" do
    # The days of these examples are fixed, and a series that tracks done cannot
    # start more than a year back.
    before do
      travel_to Time.zone.local(2026, 10, 12, 12)
      sign_in_as admin
    end

    def repeat_params(**overrides) = {frequency: "weekly", interval: "1", weekdays: ["MO", "WE"], ends: "never"}.merge(overrides)

    def create_repeating(repeat = repeat_params, **event)
      post planner_events_path, params: {planner_event: {title: "Gym", day: "2026-10-05", start_time: "18:00", end_time: "19:00", tracks_done: "1", priority: "high"}.merge(event), repeat:}
    end

    it "refuses a series that tracks done and starts more than a year back, on the day field" do
      assert_no_difference "Planner::Series.count" do
        create_repeating(repeat_params, day: "2025-10-11")
      end
      assert_response :unprocessable_content
      assert_select "#error-summary a[href='#planner_event_day']", text: /more than a year back/
    end

    it "accepts a series that does not track done, however far back it starts" do
      assert_difference "Planner::Series.count", 1 do
        create_repeating(repeat_params, day: "2020-10-05", tracks_done: "0")
      end
    end

    it "offers the repeat fields on the new form, set to never" do
      get new_planner_event_path
      assert_select "fieldset#repeat-fields legend", text: "Repeat"
      assert_select "select[name='repeat[frequency]'] option", 5
      assert_select "select[name='repeat[frequency]'] option[selected][value=never]"
      assert_select "input[name='repeat[interval]'][type=number][min='1'][max='99'][value='1']"
      assert_select "input[type=checkbox][name='repeat[weekdays][]']", 7
      assert_select "input[type=radio][name='repeat[monthly]']", 2
      assert_select "input[type=radio][name='repeat[ends]']", 3
      assert_select "input[type=date][name='repeat[until_on]']"
      assert_select "input[type=number][name='repeat[count]']"
      assert_select "[data-controller=repeat-fields][data-repeat-fields-url-value='#{planner_recurrence_summary_path}']"
    end

    it "lists the weekdays from the first weekday of the user" do
      admin.update!(first_weekday: 1)
      get new_planner_event_path
      assert_equal %w[MO TU WE TH FR SA SU], css_select("input[name='repeat[weekdays][]']").map { |box| box["value"] }
      admin.update!(first_weekday: 0)
      get new_planner_event_path
      assert_equal %w[SU MO TU WE TH FR SA], css_select("input[name='repeat[weekdays][]']").map { |box| box["value"] }
    end

    it "does not offer them to an event that already exists, nor to one made to be linked" do
      get edit_planner_event_path(planner_items(:dentist))
      assert_select "fieldset#repeat-fields", 0
      get new_planner_event_path(linked_to: planner_items(:pay_rent_task).id)
      assert_select "fieldset#repeat-fields", 0
    end

    it "makes a series, not an event, and sends the user to the first day" do
      assert_difference "Planner::Series.count", 1 do
        assert_no_difference "Planner::Event.count" do
          create_repeating
        end
      end
      series = Planner::Series.order(:id).last
      assert_equal [admin.id, "Gym", Date.new(2026, 10, 5), "18:00", 60, "FREQ=WEEKLY;BYDAY=MO,WE", 1, "high"], [series.user_id, series.title, series.starts_on, series.start_time, series.duration_minutes, series.rrule, series.tracks_done, series.priority]
      assert_equal "Europe/Rome", series.time_zone
      assert_redirected_to planner_calendar_path(date: "2026-10-05")
      assert_equal "Event created.", flash[:notice]
    end

    it "makes a series for an all-day event" do
      create_repeating(repeat_params(frequency: "monthly", monthly: "day"), start_time: "", end_time: "", day: "2026-10-31")
      series = Planner::Series.order(:id).last
      assert_equal [nil, nil, "FREQ=MONTHLY;BYMONTHDAY=31"], [series.start_time, series.duration_minutes, series.rrule]
    end

    it "makes a plain event when it does not repeat" do
      assert_difference "Planner::Event.count", 1 do
        assert_no_difference "Planner::Series.count" do
          create_repeating(repeat_params(frequency: "never"))
        end
      end
    end

    it "says every wrong thing at once and keeps what was typed" do
      assert_no_difference ["Planner::Series.count", "Planner::Event.count"] do
        create_repeating(repeat_params(frequency: "daily", interval: "0", ends: "until", until_on: ""), title: " ")
      end
      assert_response :unprocessable_content
      assert_select "#error-summary a[href='#planner_event_title']"
      assert_select "#error-summary a[href='#repeat_interval']"
      assert_select "#error-summary a[href='#repeat_until_on']"
      assert_select "select[name='repeat[frequency]'] option[selected][value=daily]"
      assert_select "input[name='repeat[interval]'][value='0']"
      assert_select "input[type=radio][name='repeat[ends]'][value=until][checked]"
    end

    it "keeps the weekdays ticked after an error" do
      create_repeating(repeat_params(interval: "100"))
      assert_response :unprocessable_content
      assert_equal %w[MO WE], css_select("input[name='repeat[weekdays][]'][checked]").map { |box| box["value"] }
    end

    it "shows the rule in words after an error, in a polite live region" do
      create_repeating(repeat_params(ends: "until", until_on: "2026-12-03"), title: " ")
      assert_select "[data-repeat-fields-target=summary][aria-live=polite]", text: "Every week on Mon, Wed, until 3 Dec 2026"
    end

    it "closes the dialog and refreshes the page behind, for a request from the dialog" do
      post planner_events_path, headers: {"Turbo-Frame" => "item-dialog-frame"}, params: {planner_event: {title: "Gym", day: "2026-10-05"}, repeat: repeat_params}
      assert_select "turbo-stream[action=close_dialog]", 1
      assert_equal 1, Planner::Series.where(title: "Gym").count
    end

    it "never lets the request choose the owner of the series, nor its place in a chain" do
      create_repeating(repeat_params, user_id: users(:other_admin).id, series_id: 1, occurrence_on: "2030-01-01")
      series = Planner::Series.order(:id).last
      assert_equal [admin.id, nil], [series.user_id, series.chain_id]
    end

    it "ignores the repeat fields of an event made to be linked" do
      assert_difference "Planner::Event.count", 1 do
        assert_no_difference "Planner::Series.count" do
          post planner_events_path, params: {planner_event: {title: "Gym", day: "2026-10-05"}, repeat: repeat_params, linked_to: planner_items(:pay_rent_task).id}
        end
      end
    end

    it "answers 422, not a crash, for junk in the repeat fields" do
      create_repeating({frequency: "weekly", interval: "x", weekdays: "MO", ends: ["a"], until_on: "99999-99-99"})
      assert_response :unprocessable_content
    end
  end
end
