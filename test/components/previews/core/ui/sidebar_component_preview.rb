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

  # The Planner group divided by sub-headings (Events, Tasks, Todos).
  def open_panel_with_sub_headings
    render(Core::UI::SidebarComponent.new(groups: subgrouped_groups, footer_items:, current_path: "/planner/schedule", open: true)) { "member@example.com" }
  end

  private

  def subgrouped_groups
    item = Core::UI::SidebarComponent::Item
    badge = Core::UI::SidebarComponent::Badge
    [
      Core::UI::SidebarComponent::Group.new(nil, [item.new("Home", "/", :home)]),
      Core::UI::SidebarComponent::Group.new("Planner", [
        item.new("Calendar", "/planner/calendar", :calendar, nil, "Events"), item.new("Agenda", "/planner/agenda", :list, nil, "Events"),
        item.new("Important", "/planner/important_events", :warning, badge.new(3, "3 important events"), "Events"),
        item.new("Missed events", "/planner/missed_events", :warning, badge.new(12, "12 missed events"), "Events"),
        item.new("Schedule", "/planner/schedule", :checklist, nil, "Tasks"), item.new("Forgotten tasks", "/planner/forgotten_tasks", :warning, badge.new(2, "2 forgotten tasks"), "Tasks"),
        item.new("Todo list", "/planner/todos", :queue_list, nil, "Todos")
      ])
    ]
  end

  def groups
    item = Core::UI::SidebarComponent::Item
    [
      Core::UI::SidebarComponent::Group.new(nil, [item.new("Home", "/", :home), item.new("Calendar", "/planner/calendar", :calendar)]),
      Core::UI::SidebarComponent::Group.new("Admin", [item.new("Users", "/admin/users", :users), item.new("Theme", "/admin/theme", :swatch)])
    ]
  end

  def footer_items = [Core::UI::SidebarComponent::Item.new("Preferences", "/preferences/edit", :cog)]
end
