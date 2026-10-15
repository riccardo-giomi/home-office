class Core::UI::LiveRegionComponentPreview < ViewComponent::Preview
  def self.page_level? = true

  # On a real page this strip is invisible: screen readers read out whatever appears in it
  # ("Event created."). It is drawn here, with a sample message, so you can see what it holds.
  def announcing
    render(Core::UI::LiveRegionComponent.new(visible: true)) { "Event created." }
  end
end
