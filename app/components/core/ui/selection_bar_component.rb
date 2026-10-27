# Shows entities currently selected.
#
# It is shown at the top of every page if it contains something, with
# information on what is selected and relative controls.
class Core::UI::SelectionBarComponent < ApplicationComponent
  # dialog_frames: the ids of the frames of dialog the page has. A record whose
  # kind opens in one of them opens there.
  def initialize(entries:, dialog_frames: [])
    @entries = entries
    @dialog_frames = dialog_frames
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
        link_to(title, destination(entity.record), class: "link inline-flex items-center min-h-6 wrap-anywhere", data: {turbo_frame: frame_for(entity.record)}),
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

  # The frame of dialog that shows the record, when the page has it.
  def frame_for(record)
    frame = Core::LinkableKind.dialog_frame_of(record)
    frame if @dialog_frames.include?(frame)
  end

  # On a page that has the dialog of the record's kind, the record's page, which
  # opens in that dialog with all its buttons. On any other page, the page and
  # view that hold the record, or its own page when its kind does not say.
  def destination(record)
    return helpers.polymorphic_path(record) if frame_for(record)

    _label, home = Core::LinkableKind.home_of(record)
    home || helpers.polymorphic_path(record)
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
