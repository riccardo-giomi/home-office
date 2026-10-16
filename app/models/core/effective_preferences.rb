# Answers "what applies right now?" for views, helpers and jobs.
# Without a browser (jobs, MCP) only the stored choices count.
class Core::EffectivePreferences
  DEFAULT_LOCALE = :en
  FALLBACK_TIME_ZONE = "UTC"
  ZONES = TZInfo::Timezone.all_identifiers.to_set.freeze

  # A String that is valid text and an IANA identifier: cookies and stored values are not trusted
  def self.valid_time_zone?(value)
    value.is_a?(String) && value.valid_encoding? && ZONES.include?(value)
  end

  def initialize(user: nil, accept_language: nil, browser_time_zone: nil, browser_theme: nil)
    @user = user
    @accept_language = accept_language
    @browser_time_zone = browser_time_zone
    @browser_theme = browser_theme
  end

  def locale
    @locale ||= stored_locale || Core::AcceptLanguage.best_match(@accept_language, available: I18n.available_locales) || DEFAULT_LOCALE
  end

  def date_format = @user&.date_format || locale_default("date_format")

  def first_weekday = @user&.first_weekday || locale_default("first_weekday")

  def time_format = @user&.time_format || locale_default("time_format")

  # A stored zone that the system no longer knows must not lock the user out: it is skipped
  def time_zone
    [@user&.time_zone, @browser_time_zone, @user&.detected_time_zone].find { |zone| self.class.valid_time_zone?(zone) } || FALLBACK_TIME_ZONE
  end

  # nil means automatic: follow the browser's color scheme. Visitors (the sign-in page) have only the cookie.
  def theme
    return @user.theme if @user

    @browser_theme if User::Preferences::THEMES.include?(@browser_theme)
  end

  private

  def stored_locale
    stored = @user&.locale&.to_sym
    stored if I18n.available_locales.include?(stored)
  end

  def locale_default(key)
    I18n.t("core.preferences.defaults.#{key}", locale:)
  end
end
