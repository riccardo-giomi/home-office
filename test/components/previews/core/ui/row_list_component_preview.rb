class Core::UI::RowListComponentPreview < ViewComponent::Preview
  # A row is a title, an optional detail line and optional actions. The detail
  # wraps to its own line on a narrow screen.
  def default = render(list)

  def long_title_and_detail
    render(Core::UI::RowListComponent.new(label: "Long rows", empty_text: "Nothing.").tap do |component|
      component.with_row(id: "long_1", detail: "Wednesday 07/10/2026 · 13:00–13:30 · Trashed 08/10/2026", actions: restore) { "A" * 100 }
    end)
  end

  def empty = render(Core::UI::RowListComponent.new(label: "Empty", empty_text: "The trash is empty."))

  private

  def list
    Core::UI::RowListComponent.new(label: "Trashed items", empty_text: "Nothing.").tap do |component|
      component.with_row(id: "row_1", detail: "07/10/2026 · 13:00–13:30 · Trashed 08/10/2026", actions: restore) { "Event: Dentist" }
      component.with_row(id: "row_2", detail: "Trashed 06/10/2026", actions: restore) { "Todo: Water the plants" }
    end
  end

  def restore = ApplicationController.new.view_context.render(Core::UI::ButtonComponent.new(variant: :secondary, size: :xs)) { "Restore" }
end
