class Core::UI::PageToolbarComponentPreview < ViewComponent::Preview
  # One per page: the Theme page leaves it out
  def self.page_level? = true

  # The main action at the start, the way to the other view at the other end (switch the theme in Lookbook's toolbar)
  def with_secondary_button
    render(toolbar)
  end

  private

  def toolbar
    component = Core::UI::PageToolbarComponent.new
    helpers = ApplicationController.helpers
    component.with_leading { helpers.link_to("New event", "#", class: "btn btn-primary") }
    component.with_trailing { helpers.link_to("Show as list", "#", class: "btn #{Core::UI::ButtonComponent::VARIANTS.fetch(:secondary)}") }
    component
  end
end
