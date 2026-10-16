module RequestPreferences
  extend ActiveSupport::Concern

  included do
    around_action :use_effective_preferences
    helper_method :effective_preferences
  end

  private

  def effective_preferences
    @effective_preferences ||= Core::EffectivePreferences.new(
      user: Current.user,
      accept_language: request.headers["Accept-Language"],
      browser_time_zone: browser_time_zone,
      browser_theme: cookie_text(:theme)
    )
  end

  # Rack has already percent-decoded the value once (decoding again would turn the "+" of
  # "Etc/GMT+5" into a space). It is attacker-controlled text, so it must also be valid UTF-8
  # before anything calls String methods on it; the name itself is checked against the IANA list later.
  def browser_time_zone = cookie_text(:time_zone)

  def cookie_text(name)
    value = cookies[name]
    value if value.is_a?(String) && value.valid_encoding?
  end

  def use_effective_preferences(&block)
    remember_detected_time_zone
    mirror_theme_cookie
    I18n.with_locale(effective_preferences.locale) do
      Time.use_zone(effective_preferences.time_zone, &block)
    end
  end

  # Jobs and MCP calls have no browser, so the last zone it reported is kept on the user
  def remember_detected_time_zone
    zone = browser_time_zone
    return unless Current.user && Core::EffectivePreferences.valid_time_zone?(zone)
    return if zone == Current.user.detected_time_zone

    Current.user.update_column(:detected_time_zone, zone)
  end

  # The cookie lets pages without a user (the sign-in page) start in the right theme
  def mirror_theme_cookie
    return unless Current.user

    if Current.user.theme
      cookies[:theme] = {value: Current.user.theme, expires: 1.year, same_site: :lax} unless cookies[:theme] == Current.user.theme
    else
      cookies.delete(:theme)
    end
  end
end
