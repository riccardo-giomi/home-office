class Core::UI::IconComponentPreview < ViewComponent::Preview
  # All the icons together, at normal and large size, to judge that they are consistent
  def all = render(Core::UI::IconGalleryComponent.new)
end
