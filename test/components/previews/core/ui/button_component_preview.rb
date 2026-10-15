# Switch the theme in Lookbook's toolbar to see each in the light and the dark theme
class Core::UI::ButtonComponentPreview < ViewComponent::Preview
  def primary
    render(Core::UI::ButtonComponent.new(type: :submit)) { "Save" }
  end

  def secondary
    render(Core::UI::ButtonComponent.new(variant: :secondary)) { "Show as list" }
  end

  def ghost
    render(Core::UI::ButtonComponent.new(variant: :ghost)) { "Sign out" }
  end

  def danger
    render(Core::UI::ButtonComponent.new(variant: :danger)) { "Delete event" }
  end

  # A link drawn as a button: it goes somewhere (a button does something)
  def as_a_link
    render(Core::UI::ButtonComponent.new(href: "#")) { "Edit event" }
  end
end
