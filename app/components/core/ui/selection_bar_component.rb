# Shows entities currently selected.
#
# It is shown at the top of every page if it contains something, with
# information on what is selected and relative controls.
class Core::UI::SelectionBarComponent < ApplicationComponent
  def initialize(entries:)
    @entries = entries
  end

  def render? = @entries.any?

  def call
    tag.div(role: "group", "aria-label": t("core.ui.selection_bar.label"), class: "mb-4 flex flex-wrap items-center gap-2 rounded border border-base-300 bg-base-100 p-2") do
      safe_join([tag.span(t("core.ui.selection_bar.selected"), class: "font-semibold"), *@entries.map { |entity| item(entity) }, actions])
    end
  end

  private

  def item(entity)
    title = entity.record.for_links.label
    label = t("core.ui.selection_bar.unselect", title:)
    tag.span(class: "inline-flex min-w-0 items-center gap-1") do
      safe_join([
        # TODO: opens the entity details in the page's body instead of the
        # usual dialog for now, make the dialog work from a layout link too.
        link_to(title, helpers.polymorphic_path(entity.record), class: "link inline-flex items-center min-h-6 wrap-anywhere"),
        form_with(url: helpers.selection_path, method: :delete, class: "inline-flex") do
          safe_join([
            hidden_field_tag(:entity_id, entity.id, id: nil),
            render(Core::UI::ButtonComponent.new(type: :submit, variant: :secondary, size: :xs, square: true, "aria-label": label, title: label)) do
              render(Core::UI::IconComponent.new(name: :x_mark, class: "size-4"))
            end
          ])
        end
      ])
    end
  end

  def actions
    tag.span(class: "ms-auto inline-flex flex-wrap gap-2") do
      safe_join([link_these_two, clear].compact)
    end
  end

  def link_these_two
    return unless @entries.size == 2

    form_with(url: helpers.links_path, method: :post) do
      safe_join([
        hidden_field_tag(:entity_id, @entries.first.id, id: nil),
        hidden_field_tag(:other_id, @entries.last.id, id: nil),
        hidden_field_tag(:clear_selection, "1", id: nil),
        render(Core::UI::ButtonComponent.new(type: :submit, size: :sm)) { t("core.ui.selection_bar.link_these") }
      ])
    end
  end

  def clear
    form_with(url: helpers.selection_path, method: :delete) do
      render(Core::UI::ButtonComponent.new(type: :submit, variant: :secondary, size: :sm)) { t("core.ui.selection_bar.clear") }
    end
  end
end
