module Core::DateTimeHelper
  def format_date(date)
    tag.time(date.strftime(date_pattern), datetime: date.iso8601)
  end

  # Zone: for a time that belongs to a place (an event keeps its own timezone),
  # not to the viewer.
  def format_time(time, zone: nil)
    local = time.in_time_zone(zone || Time.zone)
    tag.time(local.strftime(time_pattern), datetime: local.iso8601)
  end

  def format_datetime(time)
    local = time.in_time_zone
    tag.time(local.strftime("#{date_pattern} #{time_pattern}"), datetime: local.iso8601)
  end

  private

  def date_pattern = Core::DateTimePatterns::DATE.fetch(preferences.date_format)

  def time_pattern = Core::DateTimePatterns::TIME.fetch(preferences.time_format)

  # Previews render through a controller without request preferences: use the
  # locale's defaults.
  def preferences = respond_to?(:effective_preferences) ? effective_preferences : Core::EffectivePreferences.new
end
