# Page-level pieces appear once per page: Lookbook shows them, the Theme page leaves them out
class Core::UI::SkipLinkComponentPreview < ViewComponent::Preview
  def self.page_level? = true

  # Hidden until it gets keyboard focus (press Tab on a real page). Here it is focused on load so it shows.
  def focused
    render Core::UI::SkipLinkComponent.new(target: "main-content", autofocus: true)
  end
end
