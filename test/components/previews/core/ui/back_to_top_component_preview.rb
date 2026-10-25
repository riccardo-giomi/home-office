class Core::UI::BackToTopComponentPreview < ViewComponent::Preview
  # Invisible until the page has been scrolled about a screen. This preview is
  # too short to show it, so it looks empty.
  def at_rest
    render(Core::UI::BackToTopComponent.new)
  end

  # Forced visible, to look at. The header preview "with back to top" shows it
  # in place.
  def shown
    render(Core::UI::BackToTopComponent.new(shown: true))
  end
end
