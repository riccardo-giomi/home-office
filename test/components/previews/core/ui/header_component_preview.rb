class Core::UI::HeaderComponentPreview < ViewComponent::Preview
  def self.page_level? = true

  def with_page
    render(Core::UI::HeaderComponent.new(page_title: "Preferences")) { render Core::UI::ThemeSwitchComponent.new(url: "/theme") }
  end

  # With the clock (shown from 768 px up) beside the theme switch
  def with_clock
    helpers = ApplicationController.helpers
    clock = Core::UI::ClockComponent.new(zone: "Europe/Rome", date_format: "dmy", time_format: "24h", locale: "it")
    controls = helpers.safe_join([helpers.render(clock), helpers.render(Core::UI::ThemeSwitchComponent.new(url: "/theme"))])
    render(Core::UI::HeaderComponent.new(page_title: "Calendar")) { controls }
  end

  def home
    render(Core::UI::HeaderComponent.new(page_title: nil)) { render Core::UI::ThemeSwitchComponent.new(url: "/theme") }
  end

  def visitor
    render(Core::UI::HeaderComponent.new(page_title: "Sign in", menu: false)) { render Core::UI::ThemeSwitchComponent.new(url: "/theme") }
  end
end
