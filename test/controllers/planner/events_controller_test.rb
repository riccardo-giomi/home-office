require "test_helper"

class Planner::EventsControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }

  before do
    admin.update!(time_zone: "Europe/Rome", time_format: "24h", locale: "en")
    travel_to Time.utc(2026, 10, 5, 12)
  end

  describe "creating" do
    before { sign_in_as admin }

    def event_params(**overrides)
      {planner_event: {title: "Standup", day: "2026-10-09", start_time: "", end_time: "", notes: "", tracks_done: "0"}.merge(overrides)}
    end

    it "shows the form" do
      get new_planner_event_path
      assert_response :success
      assert_select "title", "New event | Home Office"
      assert_select "input[type=time]", 2
    end

    it "creates an all-day event for the signed-in user" do
      assert_difference "Planner::Event.count", 1 do
        post planner_events_path, params: event_params
      end
      event = Planner::Event.order(:id).last
      assert_equal [admin.id, "Standup", Date.new(2026, 10, 9), nil], [event.user_id, event.title, event.day, event.starts_at]
      assert_redirected_to planner_calendar_path(date: "2026-10-09")
    end

    it "creates a timed event in the user's zone with the default end" do
      post planner_events_path, params: event_params(start_time: "09:30")
      event = Planner::Event.order(:id).last
      assert_equal "Europe/Rome", event.time_zone
      assert_equal %w[09:30 10:00], [event.start_time, event.end_time]
    end

    it "never lets the request choose the owner, the state or the zone" do
      post planner_events_path, params: event_params.deep_merge(planner_event: {user_id: users(:other_admin).id, state: "cancelled", time_zone: "Asia/Tokyo", done_at: "2026-01-01"})
      event = Planner::Event.order(:id).last
      assert_equal [admin.id, "active", nil, nil], [event.user_id, event.state, event.time_zone, event.done_at]
    end

    it "keeps what was typed and answers 422 on errors" do
      assert_no_difference "Planner::Event.count" do
        post planner_events_path, params: event_params(title: " ", start_time: "10:00", end_time: "09:00", notes: "Bring the file")
      end
      assert_response :unprocessable_content
      assert_select "#error-summary"
      assert_select "input[name='planner_event[start_time]'][value='10:00']"
      assert_select "input[name='planner_event[end_time]'][value='09:00']"
      assert_select "textarea", text: /Bring the file/
    end
  end

  describe "editing" do
    before { sign_in_as admin }

    it "shows the stored values in local time" do
      get edit_planner_event_path(planner_items(:dentist))
      assert_select "input[name='planner_event[start_time]'][value='09:30']"
      assert_select "input[name='planner_event[day]'][value='2026-10-07']"
    end

    it "updates the event" do
      patch planner_event_path(planner_items(:dentist)), params: {planner_event: {title: "Dentist (moved)", start_time: "11:00", end_time: ""}}
      event = planner_items(:dentist).reload
      assert_equal ["Dentist (moved)", "11:00", "11:30"], [event.title, event.start_time, event.end_time]
      assert_redirected_to planner_event_path(event)
    end

    it "makes an event all-day when both times are cleared" do
      patch planner_event_path(planner_items(:dentist)), params: {planner_event: {start_time: "", end_time: ""}}
      assert_nil planner_items(:dentist).reload.starts_at
    end

    it "answers 422 and keeps the typed values on errors" do
      patch planner_event_path(planner_items(:dentist)), params: {planner_event: {title: "", start_time: "10:15"}}
      assert_response :unprocessable_content
      assert_select "input[name='planner_event[start_time]'][value='10:15']"
      assert_equal "Dentist", planner_items(:dentist).reload.title
    end

    it "deletes the event" do
      assert_difference "Planner::Event.count", -1 do
        delete planner_event_path(planner_items(:dentist))
      end
      assert_redirected_to planner_calendar_path(date: "2026-10-07")
    end
  end

  describe "showing" do
    before { sign_in_as admin }

    it "sends anonymous visitors to sign in" do
      sign_out
      get planner_event_path(planner_items(:dentist))
      assert_redirected_to new_session_path
    end

    it "shows the event with its day, its times in its own zone and its notes as plain text" do
      planner_items(:dentist).update!(notes: "Bring the X-rays\n<script>alert(1)</script>")
      get planner_event_path(planner_items(:dentist))
      assert_response :success
      assert_select "title", "Event: Dentist | Home Office"
      assert_select "h1", "Dentist"
      assert_select "dd time[datetime='2026-10-07']"
      assert_select "dd time[datetime='2026-10-07T09:30:00+02:00']"
      assert_select "dd", text: /Bring the X-rays/
      assert_select "script", text: /alert/, count: 0
      assert_match(/&lt;script&gt;/, response.body)
    end

    it "says all day for an event without times, and shows no notes section without notes" do
      get planner_event_path(planner_items(:holiday))
      assert_select "dd", text: /All day/
      assert_select "dt", text: "Notes", count: 0
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

    it "links back to the calendar of the event's day by default, and on to the edit form" do
      get planner_event_path(planner_items(:dentist))
      assert_select "a[href='#{planner_calendar_path(date: "2026-10-07")}']", text: "Back to calendar"
      assert_select "a[href='#{edit_planner_event_path(planner_items(:dentist))}']", text: "Edit event"
    end

    it "links back to the agenda or calendar page it came from, and carries that on" do
      back = planner_agenda_path(view: "week", date: "2026-10-07")
      get planner_event_path(planner_items(:dentist), back:)
      assert_select "a[href='#{back}']", text: "Back to agenda"
      assert_select "a[href='#{edit_planner_event_path(planner_items(:dentist), back:)}']", text: "Edit event"
      back = planner_calendar_path(view: "day", date: "2026-10-07")
      get planner_event_path(planner_items(:dentist), back:)
      assert_select "a[href='#{back}']", text: "Back to calendar"
    end

    it "ignores a back address that is not a calendar or agenda page of this app" do
      ["https://evil.example/", "//evil.example", "/admin/users", "/planner/calendar/../../session", "javascript:alert(1)", "/planner/calendar?x=<b>", "/planner/calendarx"].each do |back|
        get planner_event_path(planner_items(:dentist), back:)
        assert_response :success, back
        assert_select "a[href='#{planner_calendar_path(date: "2026-10-07")}']", text: "Back to calendar"
        assert_select "main a[href='#{back}']", count: 0
        assert_select "main a[href*='back=']", count: 0
      end
    end
  end

  describe "in the dialog of the calendar and the agenda" do
    before { sign_in_as admin }

    let(:frame) { {"Turbo-Frame" => "event-dialog-frame"} }

    it "answers a frame request with just the page, in the frame the dialog holds, without the way back" do
      get planner_event_path(planner_items(:dentist), back: planner_agenda_path), headers: frame
      assert_response :success
      assert_select "turbo-frame#event-dialog-frame h1#dialog-title", "Dentist"
      assert_select "nav#sidebar", count: 0
      assert_select "a", text: "Back to agenda", count: 0
      assert_select "a", text: "Edit event"
    end

    it "keeps the full page free of the frame, so its own forms and links behave as usual" do
      get planner_event_path(planner_items(:dentist))
      assert_select "turbo-frame", count: 0
      assert_select "h1#dialog-title", "Dentist"
      get edit_planner_event_path(planner_items(:dentist))
      assert_select "turbo-frame", count: 0
    end

    it "shows the new and edit forms in the frame, the edit form with its way back to the event" do
      get new_planner_event_path, headers: frame
      assert_select "turbo-frame#event-dialog-frame form#event-form"
      assert_select "a", text: "Back to calendar", count: 0
      get edit_planner_event_path(planner_items(:dentist)), headers: frame
      assert_select "turbo-frame#event-dialog-frame form#event-form"
      assert_select "a[href='#{planner_event_path(planner_items(:dentist))}']", text: "Back to event"
    end

    it "answers a successful change by refreshing the page behind and closing the dialog, and says so after the refresh" do
      post planner_events_path, headers: frame, params: {planner_event: {title: "Standup", day: "2026-10-09", start_time: "", end_time: "", notes: "", tracks_done: "0"}}
      assert_response :success
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_select "turbo-stream[action=refresh]:not([request-id])", 1
      assert_select "turbo-stream[action=close_dialog][target=event-dialog]", 1
      assert_equal "Event created.", flash[:notice]
      assert Planner::Event.exists?(title: "Standup")
    end

    it "does the same for an update and a delete" do
      patch planner_event_path(planner_items(:dentist)), headers: frame, params: {planner_event: {title: "Dentist 2"}}
      assert_select "turbo-stream[action=close_dialog]", 1
      assert_equal "Dentist 2", planner_items(:dentist).reload.title
      assert_equal "Event updated.", flash[:notice]
      delete planner_event_path(planner_items(:dentist)), headers: frame
      assert_select "turbo-stream[action=refresh]", 1
      assert_nil Planner::Event.find_by(id: planner_items(:dentist).id)
    end

    it "shows the errors inside the dialog, keeping what was typed" do
      post planner_events_path, headers: frame, params: {planner_event: {title: " ", day: "2026-10-09", notes: "Bring the file"}}
      assert_response :unprocessable_content
      assert_select "turbo-frame#event-dialog-frame #error-summary"
      assert_select "textarea", text: /Bring the file/
    end

    it "keeps someone else's event out of the dialog too" do
      get planner_event_path(planner_items(:other_users_event)), headers: frame
      assert_response :not_found
    end
  end

  describe "going back after a change" do
    before { sign_in_as admin }

    let(:back) { planner_agenda_path(view: "week", date: "2026-10-07") }

    it "returns to the page the visit began on after creating or deleting, and to the event after updating" do
      post planner_events_path, params: {back:, planner_event: {title: "Standup", day: "2026-10-09", start_time: "", end_time: "", notes: "", tracks_done: "0"}}
      assert_redirected_to back
      patch planner_event_path(planner_items(:dentist)), params: {back:, planner_event: {title: "Dentist 2"}}
      assert_redirected_to planner_event_path(planner_items(:dentist), back:)
      delete planner_event_path(planner_items(:dentist)), params: {back:}
      assert_redirected_to back
    end

    it "carries the back address through a form that is shown again after errors" do
      post planner_events_path, params: {back:, planner_event: {title: " ", day: "2026-10-09"}}
      assert_response :unprocessable_content
      assert_select "input[type=hidden][name=back][value='#{back}']"
    end

    it "forgets an unsafe back address instead of redirecting to it" do
      delete planner_event_path(planner_items(:dentist)), params: {back: "https://evil.example/"}
      assert_redirected_to planner_calendar_path(date: "2026-10-07")
    end
  end

  describe "someone else's event" do
    before { sign_in_as admin }

    let(:foreign) { planner_items(:other_users_event) }

    it "is not found to edit, update, delete or tick" do
      get planner_event_path(foreign)
      assert_response :not_found
      get edit_planner_event_path(foreign)
      assert_response :not_found
      patch planner_event_path(foreign), params: {planner_event: {title: "Mine now"}}
      assert_response :not_found
      patch planner_event_completion_path(foreign), params: {done: "1"}
      assert_response :not_found
      assert_no_difference "Planner::Event.count" do
        delete planner_event_path(foreign)
      end
      assert_response :not_found
      assert_equal "Someone else's secret", foreign.reload.title
    end
  end

  describe "ticking done" do
    before { sign_in_as admin }

    it "in the dialog, refreshes the page behind and redraws the details inside the dialog, keeping it open" do
      patch planner_event_completion_path(planner_items(:rent_open)), headers: {"Turbo-Frame" => "event-dialog-frame"}, params: {done: "1"}
      assert_equal "text/vnd.turbo-stream.html", response.media_type
      assert_select "turbo-stream[action=refresh]:not([request-id])", 1
      assert_select "turbo-stream[action=update][target=event-dialog-frame][method=morph] input[type=checkbox][checked]", 1
      assert_select "turbo-stream[action=update] template dd time", minimum: 2
      assert_select "turbo-stream[action=close_dialog]", 0
      assert planner_items(:rent_open).reload.done?
    end

    it "sets and clears done_at on an event that tracks it" do
      event = planner_items(:rent_open)
      patch planner_event_completion_path(event), params: {done: "1"}
      assert_redirected_to planner_calendar_path
      assert event.reload.done?
      patch planner_event_completion_path(event), params: {done: "0"}
      assert_not event.reload.done?
    end

    it "announces the change" do
      patch planner_event_completion_path(planner_items(:rent_open)), params: {done: "1"}
      assert_equal "Marked done: Rent November", flash[:notice]
      patch planner_event_completion_path(planner_items(:rent_open)), params: {done: "0"}
      assert_equal "Marked not done: Rent November", flash[:notice]
    end

    it "does nothing to an event that does not track done" do
      patch planner_event_completion_path(planner_items(:holiday)), params: {done: "1"}
      assert_nil planner_items(:holiday).reload.done_at
    end
  end
end
