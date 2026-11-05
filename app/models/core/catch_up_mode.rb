# Selects what runs the `catch_up` hook of the modules, and when.
#
# The hook (see Core::ModuleManifest) lets a module bring up to date what
# depends on the date. `HOME_OFFICE_CATCH_UP` has three values:
#
# - `lazy` (default): every request of a signed-in user runs it. It works on
#   any machine.
# - `job`: Core::CatchUpJob runs it for every active user, every hour and once
#   when the scheduler of the job queue starts. No request runs it. It needs a
#   worker.
# - `off`: nothing runs it.
#
# A page of a module can run its own catch-up, whatever the value is.
module Core::CatchUpMode
  MODES = %w[lazy job off].freeze

  # Returns the mode as a symbol: the value given (by default
  # `ENV["HOME_OFFICE_CATCH_UP"]`), or `lazy` if it is blank. Raises
  # ArgumentError for any other word, so a typo stops the app at boot.
  #
  # The environment variable is read on every call, so a test can change the
  # setting.
  def self.mode(value = ENV["HOME_OFFICE_CATCH_UP"])
    word = value.to_s.strip.downcase.presence || "lazy"
    unless MODES.include?(word)
      raise ArgumentError, "HOME_OFFICE_CATCH_UP must be one of #{MODES.join(", ")} (got #{value.inspect})"
    end

    word.to_sym
  end

  # Whether the requests of signed-in users run the catch-up.
  def self.lazy? = mode == :lazy

  # Whether Core::CatchUpJob runs the catch-up.
  def self.job? = mode == :job
end
