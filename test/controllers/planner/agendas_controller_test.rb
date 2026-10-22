require "test_helper"

class Planner::AgendasControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }

  before do
    admin.update!(time_zone: "Europe/Rome", time_format: "24h", locale: "en", first_weekday: 0)
    travel_to Time.utc(2026, 10, 5, 12)
  end

  def planner_item_selects(&block)
    queries = []
    callback = ->(*, payload) { queries << payload[:sql] if payload[:sql].match?(/\ASELECT .* FROM "planner_items"/m) }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
    queries
  end

  it "sends anonymous visitors to sign in" do
    get planner_agenda_path
    assert_redirected_to new_session_path
  end

  describe "month" do
    before { sign_in_as admin }

    it "lists the days of the month that have events, under their own headings" do
      get planner_agenda_path
      assert_response :success
      assert_select "title", "Agenda: October 2026 | Home Office"
      assert_select "h1", "Agenda"
      assert_select "h2", count: 3
      assert_select "ul li", text: /Dentist/
      assert_no_match(/Rent November|Someone else/, response.body)
    end

    it "marks an event that is not of normal priority, for a reader, and leaves the others alone" do
      planner_items(:dentist).update!(priority: "urgent")
      get planner_agenda_path
      assert_select "li", text: /Dentist/ do
        assert_select "span.badge[role=img][aria-label='Urgent priority']"
      end
      assert_select "main span.badge", count: 1
    end

    it "says so when the month is empty" do
      get planner_agenda_path(view: "month", date: "2027-03-01")
      assert_select "p", text: "No events this month."
    end

    it "moves a month at a time and offers the three views as tabs" do
      get planner_agenda_path(view: "month", date: "2026-10-15")
      assert_select "nav a[href='#{planner_agenda_path(view: "month", date: "2026-11-15")}']", text: "Next month"
      assert_select "nav a[aria-current=true]", text: "Month"
      %w[month week day].each { |view| assert_select "nav a[href='#{planner_agenda_path(view:, date: "2026-10-15")}']" }
    end
  end

  describe "week and day" do
    before { sign_in_as admin }

    it "lists the events of the week" do
      get planner_agenda_path(view: "week", date: "2026-10-07")
      assert_select "title", /Agenda: Week of 10\/04\/2026/
      assert_select "h2", count: 2
      assert_select "li", text: /Dentist/
      assert_select "li", text: /Bank holiday/
      assert_no_match(/Rent October/, response.body)
    end

    it "lists the events of one day, or says there are none" do
      get planner_agenda_path(view: "day", date: "2026-10-07")
      assert_select "li", text: /Dentist/
      assert_no_match(/Bank holiday/, response.body)
      get planner_agenda_path(view: "day", date: "2026-10-20")
      assert_select "p", text: "No events this day."
    end
  end

  it "orders a day's events by the clock on the wall, whatever zone each was made in" do
    sign_in_as admin
    Planner::Event.create!(user: admin, title: "Tokyo nine", day: Date.new(2026, 10, 20), time_zone: "Asia/Tokyo", start_time: "09:00", end_time: "10:00")
    Planner::Event.create!(user: admin, title: "Los Angeles eight", day: Date.new(2026, 10, 20), time_zone: "America/Los_Angeles", start_time: "08:00", end_time: "09:00")
    get planner_agenda_path(view: "day", date: "2026-10-20")
    assert_operator response.body.index("Los Angeles eight"), :<, response.body.index("Tokyo nine")
  end

  it "links back to the calendar of the same view and date" do
    sign_in_as admin
    %w[month week day].each do |view|
      get planner_agenda_path(view:, date: "2026-10-07")
      assert_select "div.justify-between a.btn.bg-base-100[href='#{planner_calendar_path(view:, date: "2026-10-07")}']", text: "Show in calendar"
    end
  end

  it "shows a labeled checkbox for events that track done, and the done look" do
    sign_in_as admin
    get planner_agenda_path(view: "month", date: "2026-10-01")
    assert_select "input[type=checkbox][checked][aria-label='Done: Rent October']", 1
    assert_select "s", text: "Rent October"
  end

  it "shows another user's events only to them" do
    sign_in_as users(:other_admin)
    get planner_agenda_path
    assert_match(/Someone else&#39;s secret|Someone else's secret/, response.body)
    assert_no_match(/Dentist/, response.body)
  end

  it "falls back to today and the month on odd input" do
    sign_in_as admin
    [{date: "junk"}, {date: "0000-01-01"}, {view: "banana"}, {view: "agenda"}, {view: ["x"], date: ["y"]}].each do |params|
      get planner_agenda_path(params)
      assert_response :success, params.inspect
      assert_select "title", "Agenda: October 2026 | Home Office"
    end
  end

  it "reads a month of 200 events with one query on planner_items" do
    sign_in_as admin
    200.times { |i| Planner::Event.create!(user: admin, title: "Bulk #{i}", day: Date.new(2026, 10, 1 + (i % 28))) }
    selects = planner_item_selects { get planner_agenda_path }
    assert_response :success
    assert_equal 1, selects.size, selects.inspect
  end

  it "has the dialog, and the entries and New event open their pages in it" do
    sign_in_as admin
    get planner_agenda_path
    assert_select "dialog#item-dialog turbo-frame#item-dialog-frame", 1
    assert_select "li a[data-turbo-frame=item-dialog-frame][href^='#{planner_event_path(planner_items(:dentist))}']", text: "Dentist"
    assert_select "a.btn.btn-primary[data-turbo-frame=item-dialog-frame][href^='#{new_planner_event_path}']", text: "New event"
  end

  it "opens on what is next only when the period includes today" do
    sign_in_as admin
    get planner_agenda_path(view: "month", date: "2026-10-15")
    assert_select "[data-controller=agenda-scroll]", 1
    get planner_agenda_path(view: "month", date: "2026-12-15")
    assert_select "[data-controller=agenda-scroll]", 0
  end

  describe "entries that are not active" do
    before { sign_in_as admin }

    it "say so in words and have no done box, even when the event tracks done" do
      planner_items(:cancelled_event).update_columns(tracks_done: 1)
      get planner_agenda_path(view: "day", date: "2026-10-08")
      assert_select "li", text: /Cancelled workshop/ do |entries|
        assert_match(/Cancelled/, entries.first.text)
      end
      assert_select "li", text: /All day · Cancelled/
      assert_select "input[type=checkbox][aria-label='Done: Cancelled workshop']", 0
    end
  end
end
