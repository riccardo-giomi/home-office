class Core::UI::ThemeSwitchComponentPreview < ViewComponent::Preview
  def default
    render Core::UI::ThemeSwitchComponent.new(url: "/theme")
  end
end
