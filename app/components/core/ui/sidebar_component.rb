class Core::UI::SidebarComponent < ApplicationComponent
  Group = Data.define(:label, :items)
  Badge = Data.define(:count, :label)
  Item = Data.define(:label, :path, :icon, :badge, :subgroup) do
    def initialize(label:, path:, icon:, badge: nil, subgroup: nil) = super
  end
  Run = Data.define(:heading, :items)

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

  def subgroup_id(run) = "subgroup-#{run.heading.parameterize}"

  # Splits the items of a group into runs of consecutive items with the same
  # `subgroup`. The subgroup is the heading of its run, even for a run of one
  # item. Items without a subgroup have no heading.
  def runs(group)
    group.items.chunk_while { |a, b| a.subgroup == b.subgroup }.map do |items|
      Run.new(items.first.subgroup, items)
    end
  end
end
