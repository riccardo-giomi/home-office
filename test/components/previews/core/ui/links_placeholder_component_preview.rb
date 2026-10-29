class Core::UI::LinksPlaceholderComponentPreview < ViewComponent::Preview
  def unsaved_occurrence
    render(Core::UI::LinksPlaceholderComponent.new(text: "This event repeats. A link belongs to this event only, not to the whole series.")) do
      ApplicationController.render(Core::UI::ButtonComponent.new(type: :button, variant: :secondary).with_content("Add link"), layout: false).html_safe
    end
  end
end
