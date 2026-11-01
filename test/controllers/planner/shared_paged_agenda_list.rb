# What the lists of late items (Forgotten tasks, Missed events) have in common:
# ordered by day oldest first, grouped by day, 25 items per page, and a badge in
# the sidebar with the size of the whole list. The including test defines:
#
#   list_path(**params)       the path of the page
#   page_title                the title of the page, e.g. "Forgotten tasks"
#   empty_text                the text of an empty list
#   late_item(day:, title:)   creates an item of admin that belongs on the list, dated `day`
#   badge_text(count)         the text of the sidebar badge for screen readers
#   clear_items               deletes the fixtures that belong on the list, so that a test counts only its own items
module SharedPagedAgendaList
  def self.included(base)
    base.class_eval do
      let(:admin) { users(:admin) }

      before do
        admin.update!(time_zone: "Europe/Rome", time_format: "24h", locale: "en")
        travel_to Time.utc(2026, 10, 9, 12)
      end

      it "sends an anonymous visitor to sign in" do
        get list_path
        assert_redirected_to new_session_path
      end

      describe "listing" do
        before do
          sign_in_as admin
          clear_items
        end

        it "says so when there is nothing" do
          get list_path
          assert_response :success
          assert_select "title", "#{page_title} | Home Office"
          assert_select "h1", page_title
          assert_select "main p", text: empty_text
        end

        it "lists the oldest first, grouped by day, each with a link that remembers the page" do
          late_item(day: Date.new(2026, 10, 7), title: "Newer one")
          late_item(day: Date.new(2026, 10, 2), title: "Oldest one")
          late_item(day: Date.new(2026, 10, 2), title: "Same day")
          get list_path
          assert_select "main h2", count: 2
          titles = css_select("main a").map(&:text).grep(/one|Same/)
          assert_equal ["Oldest one", "Same day", "Newer one"], titles
          assert_select "main a[href*='back=']", text: "Oldest one"
          assert_select "main input[type=checkbox]", count: 3
        end

        it "counts a day as late only once it is over in the user's zone" do
          admin.update!(time_zone: "America/New_York")
          # 22:00 on the 9th in New York, already the 10th in UTC
          travel_to Time.utc(2026, 10, 10, 2)
          late_item(day: Date.new(2026, 10, 9), title: "Still today")
          late_item(day: Date.new(2026, 10, 8), title: "Yesterday")
          get list_path
          assert_select "main a", text: "Yesterday"
          assert_select "main a", text: "Still today", count: 0
        end

        it "pages 25 at a time, with the pages labelled" do
          60.times { |index| late_item(day: Date.new(2026, 9, 1) + (index / 20), title: format("Late %02d", index + 1)) }
          get list_path
          assert_select "main a", text: "Late 25"
          assert_select "main a", text: "Late 26", count: 0
          assert_select "nav[aria-label='Pages']"
          get list_path(page: 3)
          assert_select "main a", text: "Late 60"
          assert_select "main a", text: "Late 25", count: 0
        end

        it "goes to the last page for a page that is not there, and to the first for nonsense" do
          30.times { |index| late_item(day: Date.new(2026, 9, 1), title: "Late #{index}") }
          get list_path(page: 99)
          assert_redirected_to list_path(page: 2)
          get list_path(page: "junk")
          assert_response :success
          assert_select "main a", text: "Late 0"
        end

        it "asks as many questions for sixty items as for three" do
          3.times { |index| late_item(day: Date.new(2026, 9, 1), title: "Late #{index}") }
          few = planner_item_selects { get list_path }.size
          57.times { |index| late_item(day: Date.new(2026, 9, 2), title: "More #{index}") }
          many = planner_item_selects { get list_path }.size
          assert_equal few, many
        end

        it "shows the whole list's size as the sidebar badge, on any page" do
          60.times { |index| late_item(day: Date.new(2026, 9, 1), title: "Late #{index}") }
          get root_path
          assert_select "nav a[href='#{list_path}'] span.sr-only", text: badge_text(60)
          assert_select "nav a[href='#{list_path}'] span[aria-hidden=true]", text: "60"
        end

        it "shows no badge when the list is empty" do
          get root_path
          assert_select "nav a[href='#{list_path}']"
          assert_select "nav a[href='#{list_path}'] span.badge", count: 0
        end

        it "stops the badge at 99+" do
          100.times { |index| late_item(day: Date.new(2026, 9, 1), title: "Late #{index}") }
          get root_path
          assert_select "nav a[href='#{list_path}'] span[aria-hidden=true]", text: "99+"
        end
      end
    end
  end
end
