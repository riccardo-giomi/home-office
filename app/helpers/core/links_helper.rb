# The words and buttons of the Links pages that are not components.
module Core::LinksHelper
  # The Links section of one record. The id of its entity is the record's own
  # id.
  def links_section(entity_id, notice: nil)
    ends = Core::LinkIndex.new(entity_id).ends_of(entity_id)
    linked = ends.map { |link_end| link_end.entity.id }
    other = current_selection.entries.find { |entity| entity.id != entity_id && linked.exclude?(entity.id) }
    render Core::UI::LinksSectionComponent.new(
      entity_id:, ends:, notice:,
      selected: current_selection.include?(entity_id),
      other_selected: other && [other.id, other.record.for_links.label],
      creatable: creatable_kinds(entity_id)
    )
  end

  # How many links a row has, for the strip of statuses of its entry.
  #
  # If `item` has links and the page shows them, then it returns the chip
  # ({icon:, label:, count:}); nothing otherwise.
  #
  # Uses `@link_index`, a Core::LinkIndex of the ids of the rows.
  #
  # Only the ends that are not in the trash count.
  def link_status(item)
    return unless @link_index

    count = @link_index.ends_of(item.id).count { |link_end| !link_end.trashed? }
    {icon: :link, label: t("core.ui.entry.links", count:), count:} if count.positive?
  end

  # The button that sets a record aside to link it later.
  #
  # Small and with only an icon, for the end of the strip of an entry.
  def select_command(item)
    selected = current_selection.include?(item.id)
    label = selected ? t("core.ui.links_section.unselect_short") : t("core.ui.links_section.select_short")
    render(Core::UI::SelectButtonComponent.new(entity_id: item.id, selected:, label:, title: item.title, icon: :pin))
  end

  # "Task · 07/10/2026 · Done": the kind, the day when it has one, and the
  # status when it has one.
  def link_detail(record)
    facts = record.for_links
    kind = Core::Modules.linkable_kind(facts.kind)
    parts = [(t(kind.label_key, count: 1) if kind), (format_date(facts.day) if facts.day), facts.status]
    safe_join(parts.compact, " · ")
  end

  # What a result of the picker offers: the button that makes the link, or
  # changes the one being changed, or a word that it is linked already.
  def link_candidate_action(record)
    return tag.span(t("links.new.linked"), class: "text-sm") if @linked_ids.include?(record.id)

    form_with(url: (@change ? link_path(@change) : links_path), method: (@change ? :patch : :post)) { candidate_fields(record) }
  end

  private

  def candidate_fields(record)
    safe_join([
      hidden_field_tag(:entity_id, @entity.id, id: nil),
      hidden_field_tag(:other_id, record.id, id: nil),
      hidden_field_tag(:in_section, "1", id: nil),
      render(Core::UI::ButtonComponent.new(type: :submit, size: :sm, variant: :secondary)) do
        safe_join([t("links.new.link"), tag.span(" #{record.for_links.label}", class: "sr-only")])
      end
    ])
  end

  # What "New linked" offers: each kind of every module that has a new form, as
  # [its name, the form's address].
  def creatable_kinds(entity_id)
    Core::Modules.linkable_kinds.select(&:new_route).map do |kind|
      [t(kind.label_key, count: 1), public_send(kind.new_route, linked_to: entity_id)]
    end
  end
end
