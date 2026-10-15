class Core::UI::SidebarComponentPreview < ViewComponent::Preview
  def self.page_level? = true

  # A fixed column from 1280 px wide. Narrower frames (Lookbook's default) hide it, so this example is
  # blank until you widen the viewport; the open panel below shows the small-screen look at any width.
  def with_current_page
    render(Core::UI::SidebarComponent.new(groups:, footer_items:, current_path: "/admin/users/3/edit")) { "member@example.com" }
  end

  # The panel as it looks after the menu button is pressed on a small screen
  def open_panel
    render(Core::UI::SidebarComponent.new(groups:, footer_items:, current_path: "/", open: true)) { "member@example.com" }
  end

  private

  def groups
    item = Core::UI::SidebarComponent::Item
    [
      Core::UI::SidebarComponent::Group.new(nil, [item.new("Home", "/", :home), item.new("Calendar", "/planner/calendar", :calendar)]),
      Core::UI::SidebarComponent::Group.new("Admin", [item.new("Users", "/admin/users", :users), item.new("Theme", "/admin/theme", :swatch)])
    ]
  end

  def footer_items = [Core::UI::SidebarComponent::Item.new("Preferences", "/preferences/edit", :cog)]
end
