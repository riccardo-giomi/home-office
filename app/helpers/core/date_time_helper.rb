module Core::DateTimeHelper
  def format_date(date)
    tag.time(date.strftime(date_pattern), datetime: date.iso8601)
  end

  def format_time(time)
    local = time.in_time_zone
    tag.time(local.strftime(time_pattern), datetime: local.iso8601)
  end

  def format_datetime(time)
    local = time.in_time_zone
    tag.time(local.strftime("#{date_pattern} #{time_pattern}"), datetime: local.iso8601)
  end

  private

  def date_pattern = Core::DateTimePatterns::DATE.fetch(effective_preferences.date_format)

  def time_pattern = Core::DateTimePatterns::TIME.fetch(effective_preferences.time_format)
end
