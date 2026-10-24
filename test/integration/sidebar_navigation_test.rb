require "test_helper"

class SidebarNavigationTest < ActionDispatch::IntegrationTest
  def sidebar_links = css_select("nav#sidebar a").map { |link| link.xpath("text()").text.squish }

  it "lays a member's sidebar out as Home, the Planner, then Preferences, the account box and Sign out" do
    sign_in_as users(:member)
    get root_path
    assert_equal ["Home", "Calendar", "Agenda", "Schedule", "Todos", "Preferences", "Trash"], sidebar_links
    html = response.body
    assert_operator html.index("Preferences"), :<, html.index(users(:member).email_address)
    assert_operator html.index(users(:member).email_address), :<, html.index("Sign out")
  end

  it "puts an admin's Admin group after Home and before the bottom block" do
    sign_in_as users(:admin)
    get root_path
    assert_equal ["Home", "Calendar", "Agenda", "Schedule", "Todos", "Users", "Theme", "Preferences", "Trash"], sidebar_links
    assert_equal ["Planner", "Admin"], css_select("nav#sidebar p.menu-title").map { |title| title.text.squish }
    assert_operator response.body.index("Theme"), :<, response.body.index("Preferences")
  end

  it "has no sidebar for a visitor" do
    get new_session_path
    assert_select "nav#sidebar", 0
    assert_select "header button[aria-controls=sidebar]", 0
  end

  it "shows the total in the trash beside the Trash entry, as text with a spoken label, and nothing when it is empty" do
    sign_in_as users(:admin)
    get root_path
    assert_select "nav#sidebar a[href='#{trash_path}'] .badge", text: /4/
    assert_select "nav#sidebar a[href='#{trash_path}'] .badge .sr-only", text: "4 items in the trash"
    sign_in_as users(:member)
    get root_path
    assert_select "nav#sidebar a[href='#{trash_path}']"
    assert_select "nav#sidebar a[href='#{trash_path}'] .badge", 0
  end
end
