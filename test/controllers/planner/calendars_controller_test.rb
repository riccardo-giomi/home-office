require "test_helper"

class Planner::CalendarsControllerTest < ActionDispatch::IntegrationTest
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
    get planner_calendar_path
    assert_redirected_to new_session_path
  end

  describe "month" do
    before { sign_in_as admin }

    it "shows the month of today with the user's events only" do
      get planner_calendar_path
      assert_response :success
      assert_select "title", "Calendar: October 2026 | Home Office"
      assert_select "h1", "Calendar"
      assert_select "table td", text: /Dentist/
      assert_select "table td", text: /Bank holiday/
      assert_select "table td", text: /Rent October/
      assert_no_match(/Rent November|Someone else/, response.body)
    end

    it "draws the grid from the user's first weekday" do
      get planner_calendar_path
      assert_select "thead th:first-child .sr-only", "Sunday"
      admin.update!(first_weekday: 1)
      get planner_calendar_path
      assert_select "thead th:first-child .sr-only", "Monday"
    end

    it "moves between months with plain links that keep the view" do
      get planner_calendar_path(view: "month", date: "2026-10-15")
      assert_select "nav a[href='#{planner_calendar_path(view: "month", date: "2026-11-15")}']"
      assert_select "nav a[href='#{planner_calendar_path(view: "month", date: "2026-09-15")}']"
      assert_select "nav a[href='#{planner_calendar_path(view: "month")}']", text: "Today"
      assert_select "nav a[aria-current=true]", text: "Month"
    end
  end

  describe "week" do
    before { sign_in_as admin }

    it "shows the week with times in the event's own zone" do
      admin.update!(time_zone: "America/Los_Angeles")
      Planner::Event.create!(user: admin, title: "Night shift", day: Date.new(2026, 10, 9), time_zone: "Europe/Rome",
        starts_at: Time.utc(2026, 10, 8, 22, 30), ends_at: Time.utc(2026, 10, 8, 23, 0))
      get planner_calendar_path(view: "week", date: "2026-10-07")
      assert_select "title", /Calendar: Week of 10\/04\/2026/
      assert_select "section", text: /Night shift/ do
        assert_select "time[datetime='2026-10-09T00:30:00+02:00']"
      end
      assert_select "h2", count: 7
      assert_no_match(/Rent October/, response.body)
    end

    it "puts an event at its wall-clock time on a day the clocks change" do
      admin.update!(time_zone: "Europe/Rome")
      Planner::Event.create!(user: admin, title: "Small hours", day: Date.new(2026, 10, 25), start_time: "02:30", end_time: "03:00")
      get planner_calendar_path(view: "week", date: "2026-10-25")
      assert_select "li.row-start-11", text: /Small hours/
    end
  end

  describe "day" do
    before { sign_in_as admin }

    it "shows one day as a grid, with the event at its time" do
      get planner_calendar_path(view: "day", date: "2026-10-07")
      assert_select "title", "Calendar: Wednesday 10/07/2026 | Home Office"
      assert_select "h2", count: 1
      assert_select "time[datetime='2026-10-07T09:30:00+02:00']"
      assert_no_match(/Bank holiday/, response.body)
    end

    it "moves a day at a time and keeps the view" do
      get planner_calendar_path(view: "day", date: "2026-10-07")
      assert_select "nav a[href='#{planner_calendar_path(view: "day", date: "2026-10-08")}']", text: "Next day"
      assert_select "nav a[href='#{planner_calendar_path(view: "day", date: "2026-10-06")}']", text: "Previous day"
      assert_select "nav a[href='#{planner_calendar_path(view: "day")}']", text: "Today"
    end

    it "is the only view that does not send a phone to the day view" do
      get planner_calendar_path(view: "day")
      assert_select "[data-controller~=narrow-day]", count: 0
      get planner_calendar_path(view: "month")
      assert_select "[data-controller~=narrow-day][data-narrow-day-href-value='#{planner_calendar_path(view: "day", date: "2026-10-05")}']"
      get planner_calendar_path(view: "week", date: "2026-10-07")
      assert_select "[data-controller~=narrow-day][data-narrow-day-href-value='#{planner_calendar_path(view: "day", date: "2026-10-07")}']"
    end

    it "is reached from a day number in the month grid" do
      get planner_calendar_path
      assert_select "td a[href='#{planner_calendar_path(view: "day", date: "2026-10-14")}']"
    end
  end

  describe "the list alternative" do
    before { sign_in_as admin }

    it "links to the agenda of the same view and date, in every view" do
      %w[month week day].each do |view|
        get planner_calendar_path(view:, date: "2026-10-07")
        assert_select "div.justify-between a.btn.bg-base-100[href='#{planner_agenda_path(view:, date: "2026-10-07")}']", text: "Show in Agenda"
      end
    end
  end

  describe "odd input" do
    before { sign_in_as admin }

    it "falls back to today and the month, never an error" do
      [{date: "junk"}, {date: "0000-01-01"}, {date: "9999-12-31"}, {view: "banana"}, {view: "agenda"}, {view: ["x"], date: ["y"]}, {date: "2026-02-30"}].each do |params|
        get planner_calendar_path(params)
        assert_response :success, params.inspect
        assert_select "title", "Calendar: October 2026 | Home Office"
      end
    end
  end

  describe "tick in place" do
    before { sign_in_as admin }

    it "shows a labeled checkbox only for events that track done, and the done look" do
      get planner_calendar_path
      assert_select "input[type=checkbox][checked][aria-label='Done: Rent October']", 1
      assert_select "input[type=checkbox]", 1
      assert_select "s", text: "Rent October"
    end

    it "shows the checkbox in the week and the day too" do
      get planner_calendar_path(view: "week", date: "2026-11-01")
      assert_select "input[type=checkbox][aria-label='Done: Rent November']", 1
      get planner_calendar_path(view: "day", date: "2026-11-01")
      assert_select "input[type=checkbox][aria-label='Done: Rent November']", 1
    end

    it "goes back to the page it was ticked on" do
      back = planner_calendar_url(view: "week", date: "2026-11-01")
      patch planner_event_completion_path(planner_items(:rent_open)), params: {done: "1"}, headers: {"Referer" => back}
      assert_redirected_to back
    end

    it "goes to the calendar without a referer" do
      patch planner_event_completion_path(planner_items(:rent_open)), params: {done: "1"}
      assert_redirected_to planner_calendar_path
    end
  end

  describe "scoping and cost" do
    it "shows another user's events to them and not to anyone else" do
      sign_in_as users(:other_admin)
      get planner_calendar_path
      assert_match(/Someone else&#39;s secret|Someone else's secret/, response.body)
      assert_no_match(/Dentist/, response.body)
    end

    it "reads a month of 200 events with one query on planner_items" do
      sign_in_as admin
      200.times { |i| Planner::Event.create!(user: admin, title: "Bulk #{i}", day: Date.new(2026, 10, 1 + (i % 28))) }
      selects = planner_item_selects { get planner_calendar_path }
      assert_response :success
      assert_equal 1, selects.size, selects.inspect
    end

    it "walks the day index in order, without a temporary b-tree" do
      plan = Planner::Event.owned_by(admin).on_days(Date.new(2026, 9, 27)..Date.new(2026, 10, 31)).explain.inspect
      assert_includes plan, "index_planner_items_on_day"
      assert_not_includes plan, "TEMP B-TREE"
    end
  end

  describe "events routes" do
    it "has no events list any more" do
      sign_in_as admin
      get "/planner/events"
      assert_response :not_found
    end

    it "sends the sidebar to the calendar" do
      sign_in_as users(:member)
      get root_path
      assert_select "nav a[href='#{planner_calendar_path}']", text: "Calendar"
    end
  end
end
