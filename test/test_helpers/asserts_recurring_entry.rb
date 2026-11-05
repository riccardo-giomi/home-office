require "fugit"

# Reads an entry of config/recurring.yml with environment variables set, or
# removed, for the duration of the call.
module AssertsRecurringEntry
  # Returns the entry `name` of the production section, after setting
  # `env_name` to `value` and each pair of `extra_env` (a nil value removes the
  # variable). The previous values are set back afterwards.
  def entry(name, env_name, value, extra_env = {})
    env = {env_name => value}.merge(extra_env)
    saved = env.keys.to_h { |key| [key, ENV[key]] }
    env.each { |key, word| word.nil? ? ENV.delete(key) : ENV[key] = word }
    ActiveSupport::ConfigurationFile.parse(Rails.root.join("config/recurring.yml")).dig("production", name)
  ensure
    saved.each { |key, word| word.nil? ? ENV.delete(key) : ENV[key] = word }
  end

  # Whether Solid Queue accepts the schedule: it takes cron lines and natural
  # language ones, and nothing else.
  def cron?(schedule) = Fugit.parse(schedule, multi: :fail).is_a?(Fugit::Cron)
end
