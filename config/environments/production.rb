require "active_support/core_ext/integer/time"

Rails.application.configure do
  # Settings specified here will take precedence over those in config/application.rb.

  # The Theme page renders the component previews on the server too; `enabled` stays false, so the
  # public /rails/view_components routes do not exist
  config.view_component.previews.paths = [Rails.root.join("test/components/previews").to_s]

  # Code is not reloaded between requests.
  config.enable_reloading = false

  # Eager load code on boot for better performance and memory savings (ignored by Rake tasks).
  config.eager_load = true

  # Full error reports are disabled.
  config.consider_all_requests_local = false

  # Turn on fragment caching in view templates.
  config.action_controller.perform_caching = true

  # Cache assets for far-future expiry since they are all digest stamped.
  config.public_file_server.headers = {"cache-control" => "public, max-age=#{1.year.to_i}"}

  # Enable serving of images, stylesheets, and JavaScripts from an asset server.
  # config.asset_host = "http://assets.example.com"

  # Store uploaded files on the local file system (see config/storage.yml for options).
  config.active_storage.service = :local

  # SSL is off unless HOME_OFFICE_SSL is "true" or "1", in any case. When it is
  # on, the application assumes that a proxy in front of it terminates SSL,
  # redirects plain HTTP to HTTPS, sends Strict-Transport-Security and marks
  # cookies as secure. The health check (`/up`) is never redirected, so a check
  # by plain HTTP still works.
  ssl = ENV["HOME_OFFICE_SSL"].to_s.downcase.in?(%w[1 true])
  config.assume_ssl = ssl
  config.force_ssl = ssl
  config.ssl_options = {redirect: {exclude: ->(request) { request.path == "/up" }}}

  # Action Cable accepts a connection when the Origin of the browser has the
  # scheme and the host of the request. A proxy that sends the application
  # a different host from the one the browser used, to route to one of several
  # applications for example, makes them differ, and the connection is refused.
  # HOME_OFFICE_ALLOWED_ORIGINS lists the addresses the browser uses, separated
  # by commas, such as "https://home-office.example.com:8081". When it is not
  # set, the default check stays.
  origins = ENV["HOME_OFFICE_ALLOWED_ORIGINS"].to_s.split(",").map(&:strip).compact_blank
  config.action_cable.allowed_request_origins = origins if origins.any?

  # Log to STDOUT with the current request id as a default log tag.
  config.log_tags = [:request_id]
  config.logger = ActiveSupport::TaggedLogging.logger($stdout)

  # Change to "debug" to log everything (including potentially personally-identifiable information!).
  config.log_level = ENV.fetch("RAILS_LOG_LEVEL", "info")

  # Prevent health checks from clogging up the logs.
  config.silence_healthcheck_path = "/up"

  # Don't log any deprecations.
  config.active_support.report_deprecations = false

  # Replace the default in-process memory cache store with a durable alternative.
  config.cache_store = :solid_cache_store

  # Replace the default in-process and non-durable queuing backend for Active Job.
  config.active_job.queue_adapter = :solid_queue
  config.solid_queue.connects_to = {database: {writing: :queue}}

  # The time zone in which the schedules of config/recurring.yml are read
  # ("every day at 3am"). It is the zone in HOME_OFFICE_SCHEDULE_TIME_ZONE, for
  # example Europe/Rome, and UTC if the variable is empty. A name that is not a
  # time zone stops the application at boot.
  if (zone = ENV["HOME_OFFICE_SCHEDULE_TIME_ZONE"].presence)
    config.solid_queue.time_zone = Time.find_zone!(zone)
  end

  # Ignore bad email addresses and do not raise email delivery errors.
  # Set this to true and configure the email server for immediate delivery to raise delivery errors.
  # config.action_mailer.raise_delivery_errors = false

  # Set host to be used by links generated in mailer templates.
  config.action_mailer.default_url_options = {host: "example.com"}

  # Specify outgoing SMTP server. Remember to add smtp/* credentials via bin/rails credentials:edit.
  # config.action_mailer.smtp_settings = {
  #   user_name: Rails.application.credentials.dig(:smtp, :user_name),
  #   password: Rails.application.credentials.dig(:smtp, :password),
  #   address: "smtp.example.com",
  #   port: 587,
  #   authentication: :plain
  # }

  # Enable locale fallbacks for I18n (makes lookups for any locale fall back to
  # the I18n.default_locale when a translation cannot be found).
  config.i18n.fallbacks = true

  # Do not dump schema after migrations.
  config.active_record.dump_schema_after_migration = false

  # Only use :id for inspections in production.
  config.active_record.attributes_for_inspect = [:id]

  # Enable DNS rebinding protection and other `Host` header attacks.
  # config.hosts = [
  #   "example.com",     # Allow requests from example.com
  #   /.*\.example\.com/ # Allow requests from subdomains like `www.example.com`
  # ]
  #
  # Skip DNS rebinding protection for the default health check endpoint.
  # config.host_authorization = { exclude: ->(request) { request.path == "/up" } }
end
