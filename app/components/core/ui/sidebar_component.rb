class Core::UI::SidebarComponent < ApplicationComponent
  Group = Data.define(:label, :items)
  Badge = Data.define(:count, :label)
  Item = Data.define(:label, :path, :icon, :badge) do
    def initialize(label:, path:, icon:, badge: nil) = super
  end

  # open: how the small-screen panel looks once the menu button is pressed (for previews)
  def initialize(groups:, current_path:, footer_items: [], open: false)
    @groups = groups
    @footer_items = footer_items
    @current_path = current_path
    @open = open
  end

  def render? = @groups.any?

  def current?(item) = item.path == @current_path || (item.path != "/" && @current_path.start_with?("#{item.path}/"))

  def group_id(group) = "group-#{group.label.parameterize}"
end
