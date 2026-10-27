class Core::UI::SelectionBarComponentPreview < ViewComponent::Preview
  # One record set aside: it can be unselected or cleared
  def one = render(bar([entity(1, "Pay the rent")]))

  # Two: they can be linked
  def two = render(bar([entity(2, "Pay the rent"), entity(3, "Dentist, Wednesday")]))

  def long_titles = render(bar([entity(4, "A" * 80), entity(5, "B" * 80)]))

  private

  def bar(entries) = Core::UI::SelectionBarComponent.new(entries:)

  def entity(id, title)
    record = Planner::Task.instantiate({"id" => id, "type" => "Planner::Task", "title" => title, "day" => "2026-10-07", "state" => "active", "priority" => 1, "tracks_done" => 1, "done_at" => nil})
    Core::Entity.new(id:).tap { |entity| entity.association(:record).target = record }
  end
end
