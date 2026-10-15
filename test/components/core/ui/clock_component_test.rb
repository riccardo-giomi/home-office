require "test_helper"

describe Core::UI::ClockComponent do
  include ViewComponent::TestHelpers

  let(:moment) { Time.utc(2026, 10, 7, 12, 35, 41) }

  def clock(**options)
    travel_to(moment) do
      render_inline(Core::UI::ClockComponent.new(zone: "Europe/Rome", date_format: "dmy", time_format: "24h", locale: "en", **options))
    end
  end

  it "shows the weekday, the date and the time, to the minute, in the user's zone and formats" do
    clock
    assert_selector "time[datetime='2026-10-07T14:35:00+02:00']"
    assert_selector "time", text: "14:35"
    assert_selector "time", text: "Wed 07/10/2026"
    assert_no_text "14:35:41"
  end

  it "follows the date format and the 12-hour clock" do
    clock(date_format: "ymd", time_format: "12h")
    assert_selector "time", text: "Wed 2026-10-07"
    assert_selector "time", text: "2:35 PM"
    clock(date_format: "mdy")
    assert_selector "time", text: "Wed 10/07/2026"
  end

  it "names the weekday in the user's language" do
    clock(locale: "it")
    assert_selector "time", text: /\Amer/i
  end

  it "hands the zone and the formats to the script that keeps it current" do
    clock
    assert_selector "time[data-controller=clock][data-clock-zone-value='Europe/Rome'][data-clock-date-format-value=dmy][data-clock-time-format-value='24h'][data-clock-locale-value=en]"
  end

  it "is left out below 768 px: a phone or a small tablet has a status bar of its own" do
    clock
    assert_selector "time.hidden.md\\:block", visible: :all
  end

  it "shows the date part at every width it is shown at" do
    clock
    assert_no_selector "time span.hidden", visible: :all
    assert_selector "time span[data-clock-target=date]", text: "Wed 07/10/2026"
    assert_selector "time span[data-clock-target=time]", text: "14:35"
  end

  it "is not announced every minute" do
    clock
    assert_no_selector "[aria-live]"
    assert_no_selector "time[role]"
  end
end
