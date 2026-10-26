class Core::UI::LinksSectionComponentPreview < ViewComponent::Preview
  # The Links section of a record: the other ends, a way to change or remove each, and Add link
  def default = render(section("default", [end_for(1, Planner::Task, "Pay the rent", day: "2026-10-07"), end_for(2, Planner::Todo, "Water the plants")]))

  # An end in the trash stays: last, struck through, in words, with the way to the trash
  def with_end_in_the_trash
    render(section("trash", [end_for(3, Planner::Task, "Pay the rent", day: "2026-10-07", status: "done"), end_for(4, Planner::Event, "Dentist", day: "2026-10-09", trashed: true)]))
  end

  def long_title = render(section("long", [end_for(5, Planner::Task, "A" * 120, day: "2026-10-07")]))

  def empty = render(section("empty", []))

  # What has just been done is said in a status line
  def with_notice = render(section("notice", [end_for(6, Planner::Task, "Pay the rent")], notice: "Link to Dentist removed."))

  private

  def section(name, ends, notice: nil) = Core::UI::LinksSectionComponent.new(id: "links-section-#{name}", entity_id: 99, ends:, notice:)

  def end_for(id, klass, title, day: nil, status: nil, trashed: false)
    record = klass.instantiate({"id" => id + 10, "type" => klass.sti_name, "title" => title, "day" => day || "2026-10-07", "state" => "active", "priority" => 1, "tracks_done" => 1, "done_at" => (status ? Time.current : nil)})
    entity = Core::Entity.instantiate({"id" => id + 10, "user_id" => 1, "record_type" => "Planner::Item", "deleted_at" => (trashed ? Time.current : nil)})
    link = Core::Link.instantiate({"id" => id, "first_entity_id" => 1, "second_entity_id" => id + 10, "user_id" => 1})
    Core::LinkIndex::End.new(link:, entity:, record:)
  end
end
