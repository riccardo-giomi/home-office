# Writes the errors reported with `Rails.error` to the Rails log.
#
# Rails has no subscriber by default, so an error that the code reports and
# then handles (see `Core::Modules.catch_up`) would leave no trace anywhere.
#
# `Rails.error` calls `report` on every subscriber with the error and the
# keyword arguments below. `report` must not raise.
class Core::ErrorLogSubscriber
  LEVELS = {error: :error, warning: :warn, info: :info}.freeze
  BACKTRACE_LINES = 5

  def report(error, handled:, severity:, context:, source:)
    Rails.logger.public_send(LEVELS.fetch(severity), message(error, handled:, context:, source:))
  end

  private

  def message(error, handled:, context:, source:)
    state = handled ? "handled" : "unhandled"
    lines = Rails.backtrace_cleaner.clean(error.backtrace || []).first(BACKTRACE_LINES)
    ["#{error.class}: #{error.message} (#{state}, source: #{source}, context: #{context.inspect})", *lines].join("\n")
  end
end
