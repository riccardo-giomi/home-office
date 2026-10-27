require "test_helper"

class Planner::SchedulesControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }

  before do
    admin.update!(time_zone: "Europe/Rome", time_format: "24h", locale: "en", first_weekday: 0)
    travel_to Time.utc(2026, 10, 7, 12)
  end

  it "sends anonymous visitors to sign in" do
    get planner_schedule_path
    assert_redirected_to new_session_path
  end

  describe "the day" do
    before { sign_in_as admin }

    it "is today's tasks, and nothing else, by default" do
      get planner_schedule_path
      assert_response :success
      assert_select "title", "Schedule: Wednesday 10/07/2026 | Home Office"
      assert_select "h1", "Schedule"
      assert_select "a", text: "Pay the rent"
      assert_no_match(/Buy stamps|Dentist|Someone else/, response.body)
    end

    it "shows an all-day task in the untimed strip" do
      get planner_schedule_path(date: "2026-10-08")
      assert_select "ul li", text: /All day/ do
        assert_select "a", text: "Buy stamps"
      end
    end

    it "offers the done box on a task, and says abandoned in words, without a box, on an abandoned one" do
      get planner_schedule_path
      assert_select "input[type=checkbox][aria-label='Done: Pay the rent']", 1
      get planner_schedule_path(date: "2026-10-03")
      assert_select "li", text: /Abandoned/ do
        assert_select "svg[aria-hidden=true]"
      end
      assert_select "li", text: /All day/
      assert_select "input[type=checkbox]", 0
    end

    it "shows a task on its own day and wall clock, whatever zone the viewer is in" do
      Planner::Task.create!(user: admin, title: "Night call", day: Date.new(2026, 10, 7), time_zone: "Asia/Tokyo", start_time: "23:30", end_time: "23:45")
      get planner_schedule_path(hours: "all")
      assert_select "time[datetime='2026-10-07T23:30:00+09:00']", text: "23:30"
    end

    it "does not show another user's tasks" do
      get planner_schedule_path
      assert_no_match(/Someone else/, response.body)
    end

    it "makes one query for the items of the page and one for the records its links lead to" do
      sign_in_as admin
      queries = planner_item_selects { get planner_schedule_path(view: "week") }
      assert_equal 2, queries.size, queries.inspect
    end
  end

  describe "the week" do
    before { sign_in_as admin }

    it "shows the tasks of the seven days, from the first weekday" do
      get planner_schedule_path(view: "week")
      assert_response :success
      assert_select "title", /Schedule: Week of 10\/04\/2026/
      ["Pay the rent", "Buy stamps", "Call the bank", "Renew the passport"].each { |title| assert_select "a", text: /\A#{title}/ }
      assert_select "a", text: "Sort the attic", count: 0
      assert_select "section h2", count: 7
    end

    it "sends a phone to the day" do
      get planner_schedule_path(view: "week", date: "2026-10-07")
      assert_select "[data-controller~=narrow-day][data-narrow-day-href-value='#{planner_schedule_path(view: "day", date: "2026-10-07")}']"
      get planner_schedule_path
      assert_select "[data-controller~=narrow-day]", 0
    end
  end

  describe "views and dates it does not know" do
    before { sign_in_as admin }

    it "falls back to the day of today, never an error" do
      ["month", "banana", ""].each do |view|
        get planner_schedule_path(view:)
        assert_response :success, view
        assert_select "title", /Wednesday 10\/07\/2026/
      end
      ["junk", "0000-01-01", "2026-02-30"].each do |date|
        get planner_schedule_path(date:)
        assert_response :success, date
      end
    end

    it "offers the day and the week, and nothing more" do
      get planner_schedule_path
      assert_select "nav[aria-label='Schedule navigation'] a", text: "Day"
      assert_select "nav[aria-label='Schedule navigation'] a", text: "Week"
      assert_select "nav[aria-label='Schedule navigation'] a", text: "Month", count: 0
    end
  end

  describe "the dialog" do
    before { sign_in_as admin }

    it "is there, the entries open in it, and New task is the main action" do
      get planner_schedule_path
      assert_select "dialog#item-dialog turbo-frame#item-dialog-frame", 1
      assert_select "a[data-turbo-frame=item-dialog-frame][href^='#{planner_task_path(planner_items(:pay_rent_task))}']", text: "Pay the rent"
      assert_select "a.btn.btn-primary[href^='#{new_planner_task_path}'][data-turbo-frame=item-dialog-frame]", text: "New task"
    end

    it "carries the page on, so a task opened here goes back here" do
      get planner_schedule_path(view: "week")
      assert_select "a[href*='back=#{CGI.escape(planner_schedule_path(view: "week"))}']", text: "Pay the rent"
    end
  end

  describe "in the sidebar" do
    before { sign_in_as admin }

    it "is the third entry of the Planner group, before Todos" do
      get planner_schedule_path
      assert_select "nav#sidebar ul:has(a[href='#{planner_calendar_path}']) li a" do |links|
        assert_equal %w[Calendar Agenda Schedule Todos], links.map { |link| link.text.strip }
      end
    end
  end
end
