# The words and buttons of the Links pages that are not components.
module Core::LinksHelper
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
      render(Core::UI::ButtonComponent.new(type: :submit, size: :sm, variant: :secondary)) do
        safe_join([t("links.new.link"), tag.span(" #{record.for_links.label}", class: "sr-only")])
      end
    ])
  end
end
