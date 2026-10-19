module Core::DateTimeHelper
  def format_date(date)
    tag.time(format_date_text(date), datetime: date.iso8601)
  end

  # Plain text, for page titles and labels where a <time> element does not
  # belong.
  def format_date_text(date) = date.strftime(date_pattern)

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
