# Logs the errors reported with `Rails.error`.
#
# The subscriber is created after the app has initialized because it is an
# autoloaded class.
Rails.application.config.after_initialize do
  Rails.error.subscribe(Core::ErrorLogSubscriber.new)
end
