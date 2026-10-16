require "test_helper"

class Core::DateTimeHelperTest < ActionView::TestCase
  tests Core::DateTimeHelper

  attr_reader :effective_preferences

  def with_preferences(**attributes, &block)
    @effective_preferences = Core::EffectivePreferences.new(user: User.new(attributes))
    Time.use_zone(@effective_preferences.time_zone, &block)
  end

  it "formats a date in each date format, independently of the language" do
    date = Date.new(2026, 12, 31)
    {"dmy" => "31/12/2026", "mdy" => "12/31/2026", "ymd" => "2026-12-31"}.each do |format, text|
      with_preferences(locale: "it", date_format: format) do
        assert_dom_equal %(<time datetime="2026-12-31">#{text}</time>), format_date(date)
      end
    end
  end

  it "formats a time in the user's zone, in 24-hour and 12-hour clocks" do
    time = Time.utc(2026, 10, 6, 11, 30)
    with_preferences(time_zone: "Europe/Rome", time_format: "24h") do
      assert_dom_equal %(<time datetime="2026-10-06T13:30:00+02:00">13:30</time>), format_time(time)
    end
    with_preferences(time_zone: "Europe/Rome", time_format: "12h") do
      assert_dom_equal %(<time datetime="2026-10-06T13:30:00+02:00">1:30 PM</time>), format_time(time)
    end
  end

  it "formats a time in a given zone when the time belongs to that zone, not to the viewer" do
    time = Time.utc(2026, 10, 6, 22, 30)
    with_preferences(time_zone: "America/Los_Angeles", time_format: "24h") do
      assert_dom_equal %(<time datetime="2026-10-07T00:30:00+02:00">00:30</time>), format_time(time, zone: "Europe/Rome")
      assert_dom_equal %(<time datetime="2026-10-06T15:30:00-07:00">15:30</time>), format_time(time)
    end
  end

  it "shows midnight and noon correctly in the 12-hour clock" do
    with_preferences(time_zone: "Europe/Rome", time_format: "12h") do
      _(format_time(Time.utc(2026, 10, 5, 22, 5))).must_include ">12:05 AM<"
      _(format_time(Time.utc(2026, 10, 6, 10, 30))).must_include ">12:30 PM<"
    end
  end

  it "follows the zone across a daylight-saving change" do
    with_preferences(time_zone: "Europe/Rome", time_format: "24h") do
      assert_dom_equal %(<time datetime="2026-03-29T01:30:00+01:00">01:30</time>), format_time(Time.utc(2026, 3, 29, 0, 30))
      assert_dom_equal %(<time datetime="2026-03-29T03:30:00+02:00">03:30</time>), format_time(Time.utc(2026, 3, 29, 1, 30))
    end
  end

  it "formats a date and time together and accepts times with a zone" do
    with_preferences(time_zone: "Asia/Tokyo", date_format: "ymd", time_format: "24h") do
      assert_dom_equal %(<time datetime="2026-10-06T09:30:00+09:00">2026-10-06 09:30</time>), format_datetime(Time.utc(2026, 10, 6, 0, 30).in_time_zone("UTC"))
    end
  end
end
