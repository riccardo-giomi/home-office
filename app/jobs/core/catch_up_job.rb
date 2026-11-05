# Runs the catch-up of the modules for every active user.
#
# Each user gets "today" in their own time zone. A failure for one user is
# reported and does not stop the others. The recurring schedule and the start
# of the job queue enqueue it when Core::CatchUpMode is `job`.
class Core::CatchUpJob < ApplicationJob
  queue_as :background

  def perform
    User.active.find_each do |user|
      zone = Core::EffectivePreferences.new(user:).time_zone
      Core::Modules.catch_up(user, today: Time.use_zone(zone) { Date.current })
    rescue => error
      Rails.error.report(error, handled: true)
    end
  end
end
