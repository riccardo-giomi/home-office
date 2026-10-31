# Selects who turns the past occurrences of series into events, and when.
#
# `HOME_OFFICE_CATCH_UP` has two values:
#
# - `lazy` (default): every request of a signed-in user runs it. It saves
#   events only when a series is behind, normally on the first request of the
#   day.
# - `off`: no request runs it.
#
# The Missed events page calls `run` itself, whatever the value is.
module Planner::CatchUp
  MODES = %w[lazy off].freeze

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

  def self.lazy? = mode == :lazy

  def self.run(user, today:) = Planner::Series.catch_up(user, today:)
end
