# Page-level pieces appear once per page: Lookbook shows them, the Theme page leaves them out
class Core::UI::SkipLinkComponentPreview < ViewComponent::Preview
  def self.page_level? = true

  # Hidden until it gets keyboard focus (press Tab on a real page). Here it should be focused on load.
  # If you don't see it, click in the preview area then either press Tab, or reload the preview with Ctrl+R (Cmd+R on a Mac).
  def focused
    render Core::UI::SkipLinkComponent.new(target: "main-content", autofocus: true)
  end
end
