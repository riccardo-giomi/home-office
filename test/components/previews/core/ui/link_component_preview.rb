class Core::UI::LinkComponentPreview < ViewComponent::Preview
  def default
    render(Core::UI::LinkComponent.new(href: "#")) { "Back to users" }
  end
end
