# The date and the time, to the minute, kept current by a script: for screens left open all day. It is
# drawn here once (so the first paint is right) and the script then follows the clock in the user's own
# zone and formats. Not a live region: announcing every minute would be noise. Left out below 768 px,
# where the device shows its own clock.
class Core::UI::ClockComponent < ApplicationComponent
  def initialize(zone:, date_format:, time_format:, locale:)
    @zone = zone
    @date_format = date_format
    @time_format = time_format
    @locale = locale
  end

  def call
    tag.time(safe_join([date_span, " ", time_span]), class: "hidden md:block shrink-0 px-2 text-sm tabular-nums", datetime: now.iso8601,
      data: {controller: "clock", clock_zone_value: @zone, clock_date_format_value: @date_format, clock_time_format_value: @time_format, clock_locale_value: @locale})
  end

  private

  def now = @now ||= Time.current.in_time_zone(@zone).change(sec: 0)

  def date_span
    text = "#{I18n.t("date.abbr_day_names", locale: @locale)[now.wday]} #{now.strftime(Core::DateTimePatterns::DATE.fetch(@date_format))}"
    tag.span(text, data: {clock_target: "date"})
  end

  def time_span = tag.span(now.strftime(Core::DateTimePatterns::TIME.fetch(@time_format)), data: {clock_target: "time"})
end
