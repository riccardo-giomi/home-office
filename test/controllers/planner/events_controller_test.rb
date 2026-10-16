require "test_helper"

class Planner::EventsControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }

  before do
    admin.update!(time_zone: "Europe/Rome", time_format: "24h", locale: "en")
    travel_to Time.utc(2026, 10, 5, 12)
  end

  describe "index" do
    it "sends anonymous visitors to sign in" do
      get planner_events_path
      assert_redirected_to new_session_path
    end

    it "lists the upcoming events of the signed-in user only, earliest first" do
      sign_in_as admin
      get planner_events_path
      assert_response :success
      assert_select "title", "Events | Home Office"
      titles = css_select("tbody tr").map { |row| row.text.squish }
      assert_equal ["Dentist", "Bank holiday", "Rent November"], titles.map { |t| t[/Dentist|Bank holiday|Rent November/] }
      assert_no_match(/Rent October|Someone else/, response.body)
    end

    it "shows the time in the user's zone and says all day for untimed events" do
      sign_in_as admin
      get planner_events_path
      assert_select "time[datetime='2026-10-07T09:30:00+02:00']", text: "09:30"
      assert_select "tbody tr", text: /Bank holiday.*All day|All day.*Bank holiday/m
    end

    it "shows an event's time in the event's own zone, matching its day, whatever zone the viewer is in" do
      admin.update!(time_zone: "America/Los_Angeles")
      Planner::Event.create!(user: admin, title: "Night shift", day: Date.new(2026, 10, 9), time_zone: "Europe/Rome",
        starts_at: Time.utc(2026, 10, 8, 22, 30), ends_at: Time.utc(2026, 10, 8, 23, 0))
      sign_in_as admin
      get planner_events_path
      assert_select "tr", text: /Night shift/ do
        assert_select "time[datetime='2026-10-09T00:30:00+02:00']", text: "00:30"
      end
    end

    it "lists past events, latest first, with when=past" do
      sign_in_as admin
      get planner_events_path(when: "past")
      assert_select "tbody tr", count: 1
      assert_match(/Rent October/, response.body)
      assert_no_match(/Dentist/, response.body)
    end

    it "treats an unknown when as upcoming" do
      sign_in_as admin
      get planner_events_path(when: "whenever")
      assert_match(/Dentist/, response.body)
    end

    it "paginates and marks the current page" do
      sign_in_as admin
      26.times { |i| Planner::Event.create!(user: admin, title: "Bulk #{i}", day: Date.new(2026, 12, 1) + i) }
      get planner_events_path(page: 2)
      assert_response :success
      assert_select "nav[aria-label] a[aria-current=page]", text: "2"
    end

    it "keeps the page tolerant of junk page numbers" do
      sign_in_as admin
      ["99", "abc", "-1", "0"].each do |page|
        get planner_events_path(page:)
        assert_response :success, "page=#{page}"
      end
    end

    it "does not show the pagination nav for a single page" do
      sign_in_as admin
      get planner_events_path
      assert_select "nav[aria-label='Pages']", count: 0
    end

    it "shows who has done what: a done event is marked with text and strike-through" do
      sign_in_as admin
      get planner_events_path(when: "past")
      assert_select "tr", text: /Rent October/ do
        assert_select "s", text: "Rent October"
        assert_select ".sr-only", text: "Done"
      end
    end
  end

  describe "navigation" do
    it "adds Events to the sidebar of a plain user" do
      sign_in_as users(:member)
      get root_path
      assert_select "nav a[href='#{planner_events_path}']", text: "Events"
    end
  end
  describe "showing" do
    it "shows an event's details in its own zone, with the notes and a way to edit it" do
      event = planner_items(:dentist)
      event.update!(notes: "Bring the X-rays")
      sign_in_as admin
      get planner_event_path(event)
      assert_response :success
      assert_select "h1", text: "Dentist"
      assert_select "dd", text: /09:30/
      assert_select "dd", text: /Bring the X-rays/
      assert_select "a[href='#{edit_planner_event_path(event)}']"
      assert_select "a[href='#{planner_events_path}']", text: I18n.t("planner.events.back")
    end

    it "offers the done checkbox only when the event tracks done" do
      sign_in_as admin
      get planner_event_path(planner_items(:rent_open))
      assert_select "input[type=checkbox][name=done]"
      get planner_event_path(planner_items(:dentist))
      assert_select "input[type=checkbox][name=done]", 0
    end

    it "is not found for someone else's event" do
      sign_in_as admin
      get planner_event_path(planner_items(:other_users_event))
      assert_response :not_found
    end
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
      assert_redirected_to planner_events_path
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
      assert_redirected_to planner_events_path
      event = planner_items(:dentist).reload
      assert_equal ["Dentist (moved)", "11:00", "11:30"], [event.title, event.start_time, event.end_time]
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
      assert_redirected_to planner_events_path
    end
  end

  describe "someone else's event" do
    before { sign_in_as admin }

    let(:foreign) { planner_items(:other_users_event) }

    it "is not found to edit, update, delete or tick" do
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

    it "sets and clears done_at on an event that tracks it" do
      event = planner_items(:rent_open)
      patch planner_event_completion_path(event), params: {done: "1"}
      assert_redirected_to planner_events_path
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

    it "shows a labeled checkbox only for events that track done" do
      get planner_events_path
      assert_select "input[type=checkbox][aria-label='Done: Rent November']", 1
      assert_select "input[type=checkbox]", 1
      get planner_events_path(when: "past")
      assert_select "input[type=checkbox][checked][aria-label='Done: Rent October']", 1
    end
  end
end
