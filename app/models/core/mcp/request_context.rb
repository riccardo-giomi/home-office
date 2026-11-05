# What a request of the MCP endpoint has in place of a browser.
#
# The stored choices of the user (time zone, first weekday), English for the
# words that agents read, and the catch-up of the modules with "today" in the
# time zone of the user.
module Core::Mcp::RequestContext
  def self.run(user)
    preferences = Core::EffectivePreferences.new(user:)
    Current.first_weekday = preferences.first_weekday
    I18n.with_locale(:en) do
      Time.use_zone(preferences.time_zone) do
        Core::Modules.catch_up(user, today: Date.current)
        yield
      end
    end
  end
end
