# Runs the `catch_up` hook of every module for the signed-in user, before the
# action. The Planner uses it to turn the occurrences up to yesterday into
# events.
#
# Include it after RequestPreferences, which sets the time zone, so `today` is
# the date in the user's time zone.
#
# It does nothing for visitors who are not signed in.
module Core::CatchUp
  extend ActiveSupport::Concern

  included do
    before_action :catch_up_modules
  end

  private

  def catch_up_modules
    Core::Modules.catch_up(Current.user, today: Date.current) if Current.user
  end
end
