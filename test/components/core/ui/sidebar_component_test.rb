require "test_helper"

describe Core::UI::SidebarComponent do
  include ViewComponent::TestHelpers

  def render_sidebar(current_path, groups: default_groups)
    render_inline(Core::UI::SidebarComponent.new(groups:, current_path:)) { "footer" }
  end

  def default_groups
    item = Core::UI::SidebarComponent::Item
    group = Core::UI::SidebarComponent::Group
    [group.new(nil, [item.new("Home", "/", :home)]), group.new("Admin", [item.new("Users", "/admin/users", :users)])]
  end

  it "is the labeled main navigation with titled groups and the footer" do
    render_sidebar("/")
    assert_selector "nav#sidebar[aria-label='#{I18n.t("core.ui.sidebar.label")}'][data-sidebar-target=panel]", visible: :all
    assert_selector "nav p#group-admin", text: "Admin", visible: :all
    assert_selector "nav ul[aria-labelledby=group-admin] a", text: "Users", visible: :all
    assert_text "footer"
  end

  it "puts the footer links in a list of their own, above the footer content" do
    item = Core::UI::SidebarComponent::Item
    render_inline(Core::UI::SidebarComponent.new(groups: default_groups, footer_items: [item.new("Preferences", "/preferences/edit", :cog)], current_path: "/preferences/edit")) { "account box" }
    assert_selector "nav#sidebar ul[data-part=footer-links] a[aria-current=page]", text: "Preferences", visible: :all
    html = page.native.to_html
    assert_operator html.index("Preferences"), :<, html.index("account box")
    assert_operator html.index("Users"), :<, html.index("Preferences")
  end

  it "has no footer list when there are no footer links" do
    render_sidebar("/")
    assert_no_selector "ul[data-part=footer-links]", visible: :all
  end

  it "can be rendered open, as the small-screen panel looks after the menu button is pressed" do
    render_inline(Core::UI::SidebarComponent.new(groups: default_groups, current_path: "/", open: true)) { "footer" }
    assert_selector "nav#sidebar[data-open]", visible: :all
    render_sidebar("/")
    assert_no_selector "nav#sidebar[data-open]", visible: :all
  end

  it "marks the current page and its sub-pages, not look-alikes" do
    render_sidebar("/admin/users/3/edit")
    assert_selector "a[aria-current=page]", text: "Users", visible: :all
    assert_no_selector "a[aria-current=page]", text: "Home", visible: :all
    render_sidebar("/admin/users-archive")
    assert_no_selector "a[aria-current]", visible: :all
  end

  it "marks Home only on the root path, and with more than color" do
    render_sidebar("/")
    assert_selector "a[aria-current=page].font-bold", text: "Home", visible: :all
  end

  it "gives every entry a decorative icon and has a close button for small screens" do
    render_sidebar("/")
    assert_selector "nav a svg[aria-hidden=true]", count: 2, visible: :all
    assert_selector "nav button[data-action='sidebar#close']", text: I18n.t("core.ui.sidebar.close"), visible: :all
    assert_selector "[data-sidebar-target=backdrop][aria-hidden=true]", visible: :all
  end

  it "renders nothing without groups (visitors)" do
    render_inline(Core::UI::SidebarComponent.new(groups: [], current_path: "/"))
    assert_no_selector "nav", visible: :all
  end
end
