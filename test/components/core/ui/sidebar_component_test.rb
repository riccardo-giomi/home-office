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

  it "draws a badge after the label of an item that has a count, and nothing for a zero or no count" do
    item = Core::UI::SidebarComponent::Item
    badge = Core::UI::SidebarComponent::Badge
    groups = [Core::UI::SidebarComponent::Group.new(nil, [item.new("Home", "/", :home), item.new("Trash", "/trash", :list, badge.new(2, "2 tasks")), item.new("Zero", "/zero", :list, badge.new(0, "0 tasks"))])]
    render_inline(Core::UI::SidebarComponent.new(groups:, current_path: "/")) { "footer" }
    assert_selector "nav a[href='/trash'] span.badge", text: /2/, visible: :all
    assert_selector "nav a[href='/trash'] .sr-only", text: "2 tasks", visible: :all
    assert_no_selector "nav a[href='/zero'] span.badge", visible: :all
    assert_no_selector "nav a[href='/'] span.badge", visible: :all
  end

  describe "sub-headings" do
    def subgrouped
      item = Core::UI::SidebarComponent::Item
      [Core::UI::SidebarComponent::Group.new("Planner", [
        item.new("Calendar", "/planner/calendar", :calendar, nil, "Events"), item.new("Agenda", "/planner/agenda", :list, nil, "Events"),
        item.new("Schedule", "/planner/schedule", :checklist, nil, "Tasks"), item.new("Forgotten", "/planner/forgotten_tasks", :warning, nil, "Tasks"),
        item.new("Todo list", "/planner/todos", :queue_list, nil, "Todos")
      ])]
    end

    it "draws a static heading before each run of items, each run its own list labelled by it" do
      render_sidebar("/planner/agenda", groups: subgrouped)
      assert_selector "nav p.menu-title", count: 4, visible: :all
      assert_selector "nav p#subgroup-events", text: "Events", visible: :all
      assert_selector "nav ul[aria-labelledby=subgroup-events] a", count: 2, visible: :all
      assert_selector "nav ul[aria-labelledby=subgroup-tasks] a", text: "Forgotten", visible: :all
      assert_no_selector "nav p#subgroup-events a, nav p#subgroup-events button", visible: :all
    end

    it "draws a heading above a run of one item" do
      render_sidebar("/", groups: subgrouped)
      assert_selector "nav p#subgroup-todos", text: "Todos", visible: :all
      assert_selector "nav ul[aria-labelledby=subgroup-todos] a", count: 1, text: "Todo list", visible: :all
    end

    it "draws no heading for an item with no subgroup, and gives its list the group's label" do
      item = Core::UI::SidebarComponent::Item
      render_sidebar("/", groups: [Core::UI::SidebarComponent::Group.new("Planner", [item.new("Calendar", "/c", :calendar)])])
      assert_selector "nav p.menu-title", count: 1, visible: :all
      assert_selector "nav ul[aria-labelledby=group-planner] a", count: 1, text: "Calendar", visible: :all
    end

    it "still marks the current page inside a subgroup" do
      render_sidebar("/planner/schedule", groups: subgrouped)
      assert_selector "nav ul[aria-labelledby=subgroup-tasks] a[aria-current=page]", text: "Schedule", visible: :all
    end
  end
end
