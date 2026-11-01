require "test_helper"

class Planner::ImportantEventsControllerTest < ActionDispatch::IntegrationTest
  let(:admin) { users(:admin) }

  before do
    admin.update!(time_zone: "Europe/Rome", time_format: "24h", locale: "en")
    travel_to Time.utc(2026, 10, 9, 12)
  end

  def event(title, day: Date.new(2026, 10, 9), priority: "urgent", **attrs) = Planner::Event.create!({user: admin, title:, day:, priority:}.merge(attrs))

  def titles = css_select("main li a").reject { |link| link.ancestors("nav").any? }.map(&:text)

  it "sends an anonymous visitor to sign in" do
    get planner_important_events_path
    assert_redirected_to new_session_path
  end

  describe "the page" do
    before { sign_in_as admin }

    it "says so when there is nothing" do
      get planner_important_events_path
      assert_response :success
      assert_select "title", "Important | Home Office"
      assert_select "h1", "Important"
      assert_select "main p", text: "Nothing important in the next 7 days."
    end

    it "lists urgent events earliest first, grouped by day, with a link that remembers the page" do
      event("Later", day: Date.new(2026, 10, 14))
      event("Sooner", day: Date.new(2026, 10, 10))
      event("Same day", day: Date.new(2026, 10, 10))
      event("Normal", priority: "normal")
      get planner_important_events_path
      assert_equal ["Sooner", "Same day", "Later"], titles
      assert_select "main h2", count: 2
      assert_select "main a[href*='back=']", text: "Sooner"
    end

    it "shows a series once, by its nearest date, drawn from the rule" do
      Planner::Series.create!(user: admin, title: "Standup", priority: "urgent", starts_on: Date.new(2026, 10, 1), time_zone: "Europe/Rome", rrule: "FREQ=DAILY")
      get planner_important_events_path
      assert_equal ["Standup"], titles
      assert_equal 0, Planner::Event.where(title: "Standup", day: Date.new(2026, 10, 9)..).count
    end

    it "takes the horizon and the minimum from the address, and says which are chosen" do
      event("High one", priority: "high", day: Date.new(2026, 10, 20))
      get planner_important_events_path(horizon: "30d", minimum: "high")
      assert_equal ["High one"], titles
      assert_select "nav[aria-label='Horizon'] a[aria-current=true]", text: "30 days"
      assert_select "nav[aria-label='Priority'] a[aria-current=true]", text: "Urgent and high"
      assert_select "nav[aria-label='Horizon'] a[href='#{planner_important_events_path(horizon: "6m", minimum: "high")}']", text: "6 months"
      assert_select "nav[aria-label='Priority'] a[href='#{planner_important_events_path(horizon: "30d", minimum: "urgent")}']", text: "Urgent"
    end

    it "is the fourth tab of the agenda views, the current one" do
      get planner_important_events_path
      assert_select "nav[aria-label='Agenda views'] a[href='#{planner_agenda_path(view: "month")}']", text: "Month"
      assert_select "nav[aria-label='Agenda views'] a[aria-current=true]", text: /Important/
    end

    it "does not grow in questions with the number of events" do
      3.times { |index| event("Few #{index}") }
      few = planner_item_selects { get planner_important_events_path }.size
      40.times { |index| event("More #{index}", day: Date.new(2026, 10, 10 + (index % 5))) }
      many = planner_item_selects { get planner_important_events_path }.size
      assert_equal few, many
    end
  end

  describe "the agenda" do
    before { sign_in_as admin }

    it "has the tab, with the count of what the page lists by default" do
      event("One")
      event("Two", day: Date.new(2026, 10, 10))
      get planner_agenda_path
      assert_select "nav a[href='#{planner_important_events_path}']", text: /Important/ do
        assert_select "span.sr-only", text: "2 important events"
      end
    end
  end

  describe "the sidebar" do
    before { sign_in_as admin }

    it "has an entry with a badge that counts the default list, whatever the page filters" do
      event("One")
      event("Far", day: Date.new(2026, 12, 1))
      get planner_important_events_path(horizon: "1y", minimum: "high")
      assert_select "nav#sidebar a[href='#{planner_important_events_path}'] span.sr-only", text: "1 important event"
    end

    it "has no badge when nothing is important" do
      get root_path
      assert_select "nav#sidebar a[href='#{planner_important_events_path}']"
      assert_select "nav#sidebar a[href='#{planner_important_events_path}'] span.badge", count: 0
    end
  end
end
