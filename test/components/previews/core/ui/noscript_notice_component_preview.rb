class Core::UI::NoscriptNoticeComponentPreview < ViewComponent::Preview
  def self.page_level? = true

  # On a real page this covers everything only when JavaScript is off. Shown here as it would look then.
  def without_javascript
    render Core::UI::NoscriptNoticeComponent.new(shown: true)
  end
end
