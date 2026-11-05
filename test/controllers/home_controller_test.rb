require "test_helper"

class HomeControllerTest < ActionDispatch::IntegrationTest
  it "serves the placeholder home page to a signed-in user" do
    sign_in_as users(:admin)
    get root_path
    assert_response :success
    assert_select "h1", text: I18n.t("home.show.title")
  end

  it "links to the settings page" do
    sign_in_as users(:member)
    get root_path
    assert_select "a[href=?]", settings_path
  end

  it "sends an anonymous visitor to sign in" do
    get root_path
    assert_redirected_to new_session_path
  end

  describe "the dashboard" do
    # A title with a narrow link has two anchors and CSS hides one of them; the
    # test reads the first
    def cards = css_select("main article h2").map { |heading| [heading.css("a").first.text, heading.css("[data-part=total]").first&.text].compact.join(" ") }

    it "has four cards of zeros for a user with nothing, never an empty page" do
      Planner::Item.delete_all
      sign_in_as users(:member)
      get root_path
      assert_equal ["Events", "Tasks", "Todos 0 to do", "Trash 0 items"], cards
      assert_select "main article li a", count: 13
      assert_select "main article:has(h2 a[href='#{planner_calendar_path}']) li a", text: /0 Missed events/
    end

    it "gives each line the place it counts, with the other layout's link beside it" do
      sign_in_as users(:member)
      get root_path
      assert_select "main article li a[href='#{planner_missed_events_path}']"
      assert_select "main article li a.hidden[href^='#{planner_calendar_path}?']"
      assert_select "main article li a[href^='#{planner_agenda_path}?'][class~='sm:hidden']"
    end

    it "counts what the lists hold" do
      user = users(:member)
      Planner::Item.delete_all
      Planner::Todo.create!(user:, title: "Urgent", priority: "urgent")
      Planner::Event.create!(user:, title: "Missed", day: Date.current - 2, tracks_done: 1)
      sign_in_as user
      get root_path
      assert_select "main article li a[href='#{planner_missed_events_path}']", text: /1 Missed events/
      assert_select "main article li a[href='#{planner_todos_path}']", text: /1 Urgent/
      assert_equal "Todos 1 to do", cards[2]
    end

    it "speaks Italian" do
      user = users(:member)
      user.update!(locale: "it")
      sign_in_as user
      get root_path
      assert_select "main article h2 a", text: "Eventi"
      assert_select "main article h2 a", text: "Attività"
      assert_select "main article h2 a", text: "Cestino"
    end

    it "keeps the signed in line" do
      sign_in_as users(:member)
      get root_path
      assert_select "main p", text: /#{Regexp.escape(users(:member).email_address)}/
    end

    it "is not kept by Turbo for the Back button, which would bring back old numbers" do
      sign_in_as users(:member)
      get root_path
      assert_select "meta[name=turbo-cache-control][content=no-cache]", count: 1
    end
  end
end
