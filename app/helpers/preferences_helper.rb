module PreferencesHelper
  def automatic_choice = [t("preferences.automatic"), ""]

  def locale_choices
    [automatic_choice] + I18n.available_locales.map do |locale|
      [t("preferences.locales.#{locale}"), locale.to_s]
    end
  end

  def date_format_choices
    [automatic_choice] + User::Preferences::DATE_FORMATS.map do |format|
      [t("preferences.date_formats.#{format}"), format]
    end
  end

  def time_format_choices
    [automatic_choice] + User::Preferences::TIME_FORMATS.map do |format|
      [t("preferences.time_formats.#{format}"), format]
    end
  end

  def theme_choices
    [automatic_choice] + User::Preferences::THEMES.map do |theme|
      [t("preferences.themes.#{theme}"), theme]
    end
  end

  # date.day_names starts on Sunday, matching first_weekday 0
  def weekday_choices
    [automatic_choice] + t("date.day_names").each_with_index.map do |name, index|
      [name.capitalize, index]
    end
  end

  # The hours of the day, written the way the grids write them. The value is
  # the whole hour.
  def hour_choices
    (0..23).map { |hour| [format_time_text(Time.utc(2000, 1, 1, hour), zone: "UTC"), hour] }
  end

  def time_zone_choices
    [automatic_choice] + ActiveSupport::TimeZone.all.map do |zone|
      [zone.to_s, zone.tzinfo.name]
    end.uniq(&:last)
  end

  def first_weekday_name = t("date.day_names")[effective_preferences.first_weekday].capitalize
end
