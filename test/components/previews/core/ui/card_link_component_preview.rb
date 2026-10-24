class Core::UI::CardLinkComponentPreview < ViewComponent::Preview
  def default = render(Core::UI::CardLinkComponent.new(href: "#", title: "Planner", caption: "In the trash:", lines: ["12 events", "3 tasks", "0 todos"]))

  def without_caption = render(Core::UI::CardLinkComponent.new(href: "#", title: "Planner", lines: ["12 events"]))

  def long_words = render(Core::UI::CardLinkComponent.new(href: "#", title: "A module with a very long name indeed", caption: "In the trash:", lines: ["1234567 events", "Supercalifragilisticexpialidocious items"]))
end
