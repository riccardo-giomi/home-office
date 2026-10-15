class Core::UI::TabsComponentPreview < ViewComponent::Preview
  def views_of_a_period
    render(Core::UI::TabsComponent.new(label: "Views", items: [["Month", "#month", false], ["Week", "#week", true], ["Day", "#day", false]]))
  end

  # More tabs than fit one line wrap instead of overflowing
  def many_tabs
    render(Core::UI::TabsComponent.new(label: "Scopes", items: ["Month", "Week", "Day", "Important", "Overdue", "Done recently"].each_with_index.map { |name, index| [name, "#", index == 3] }))
  end
end
