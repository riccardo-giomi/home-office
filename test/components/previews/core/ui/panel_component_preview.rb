class Core::UI::PanelComponentPreview < ViewComponent::Preview
  def default = render(Core::UI::PanelComponent.new(title: "Add a link", id: "panel")) { "What the panel holds goes here." }
end
