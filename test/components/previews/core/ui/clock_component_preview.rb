class Core::UI::ClockComponentPreview < ViewComponent::Preview
  # One per page, in the header: the Theme page leaves it out
  def self.page_level? = true

  def twenty_four_hour_clock
    render(Core::UI::ClockComponent.new(zone: "Europe/Rome", date_format: "dmy", time_format: "24h", locale: "en"))
  end

  def twelve_hour_clock_in_italian
    render(Core::UI::ClockComponent.new(zone: "America/New_York", date_format: "mdy", time_format: "12h", locale: "it"))
  end
end
