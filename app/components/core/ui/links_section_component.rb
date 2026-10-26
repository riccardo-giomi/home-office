# The Links section of a record's page or dialog.
#
# It lists the other end of each link (kind, title, day, status) with a way to
# change or remove it, a button to add a link, and the frame the picker is
# drawn in. It knows nothing of what the records are: the ends come from
# Core::LinkIndex.
#
# A link to a record in the trash stays, last, struck through and said in
# words.
#
# The section is a labeled group, not a landmark, because the Theme page shows
# several of them.
class Core::UI::LinksSectionComponent < ApplicationComponent
  # id: the section's element id, which the server's streams aim at. A page has
  # one section; the previews on the Theme page give each their own. The
  # heading and the picker's frame are named after it.
  #
  # notice: what has just been done, said in a status line. The dialog hides
  # the page's own notice.
  def initialize(entity_id:, ends:, notice: nil, id: "links-section")
    @id = id
    @entity_id = entity_id
    @ends = ends
    @notice = notice
  end

  def call
    tag.div(id: @id, role: "group", "aria-labelledby": heading_id, class: "mt-8") do
      safe_join([heading, status, list, buttons, tag.turbo_frame(id: picker_id)].compact)
    end
  end

  private

  def heading_id = "#{@id}-heading"

  def picker_id = "#{@id}-picker"

  # The count is of the links to records that are not in the trash.
  def heading
    count = @ends.count { |link_end| !link_end.trashed? }
    tag.h2(t("core.ui.links_section.heading", count:), id: heading_id, tabindex: -1, class: "mb-2 text-lg font-semibold focus:outline-none")
  end

  def status = (tag.p(@notice, role: "status", class: "mb-2 text-sm") if @notice)

  def list
    render(Core::UI::RowListComponent.new(label: t("core.ui.links_section.list"), empty_text: t("core.ui.links_section.none"))) do |rows|
      @ends.each do |link_end|
        rows.with_row(id: "link_#{link_end.link.id}", detail: detail(link_end), actions: actions(link_end)) { title(link_end) }
      end
    end
  end

  def title(link_end)
    return tag.s(link_end.label, class: "opacity-70 wrap-anywhere") if link_end.trashed?

    link_to(link_end.label, helpers.polymorphic_path(link_end.record), class: "link inline-flex items-center min-h-6 wrap-anywhere")
  end

  def detail(link_end)
    kind = Core::Modules.linkable_kind(link_end.kind_key)
    parts = [(t(kind.label_key, count: 1) if kind), (helpers.format_date(link_end.day) if link_end.day), link_end.status]
    parts << t("core.ui.links_section.in_trash") if link_end.trashed?
    safe_join([safe_join(parts.compact, " · "), (trash_link if link_end.trashed?)].compact, " ")
  end

  # Core cannot name the Planner's trash page: the link goes to the trash hub.
  def trash_link = link_to(t("core.ui.links_section.to_trash"), helpers.trash_path, class: "link inline-flex items-center min-h-6")

  def actions(link_end)
    tag.div(class: "flex shrink-0 flex-wrap items-center gap-2") do
      safe_join([change_button(link_end), remove_button(link_end)])
    end
  end

  def change_button(link_end)
    href = helpers.new_link_path(entity_id: @entity_id, kind: link_end.kind_key, change: link_end.link.id)
    render(Core::UI::ButtonComponent.new(variant: :secondary, size: :xs, href:, data: {turbo_frame: picker_id})) do
      safe_join([t("core.ui.links_section.change"), tag.span(" #{link_end.label}", class: "sr-only")])
    end
  end

  def remove_button(link_end)
    label = t("core.ui.links_section.remove", title: link_end.label)
    form_with(url: helpers.link_path(link_end.link), method: :delete) do
      safe_join([
        hidden_field_tag(:entity_id, @entity_id, id: nil),
        hidden_field_tag(:in_section, "1", id: nil),
        render(Core::UI::ButtonComponent.new(type: :submit, variant: :secondary, size: :xs, square: true, "aria-label": label, title: label)) do
          render(Core::UI::IconComponent.new(name: :x_mark, class: "size-4"))
        end
      ])
    end
  end

  def buttons
    tag.div(class: "mt-3 flex flex-wrap gap-2") do
      safe_join([add_link].compact)
    end
  end

  def add_link
    render(Core::UI::ButtonComponent.new(variant: :secondary, href: helpers.new_link_path(entity_id: @entity_id), data: {turbo_frame: picker_id})) do
      t("core.ui.links_section.add")
    end
  end
end
