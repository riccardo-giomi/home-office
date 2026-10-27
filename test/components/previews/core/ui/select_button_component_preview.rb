class Core::UI::SelectButtonComponentPreview < ViewComponent::Preview
  # On a row: short, the title is for the reader
  def on_a_row = render(Core::UI::SelectButtonComponent.new(entity_id: 1, selected: false, label: "Select", title: "Pay the rent", size: :xs))

  def selected_on_a_row = render(Core::UI::SelectButtonComponent.new(entity_id: 2, selected: true, label: "Unselect", title: "Pay the rent", size: :xs))

  # In a Links section: the whole record, full size
  def in_a_section = render(Core::UI::SelectButtonComponent.new(entity_id: 3, selected: false, label: "Select this record", in_section: true))
end
