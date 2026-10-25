# Which hours of the day a time grid shows: the user's day hours, the hours
# around them, or all of them.
#
# The end hour is shown whole: 7 and 21 show 07:00 to 22:00. Answers are
# minutes from midnight. Anything unreadable is read as the day hours.
class Core::DaySlice
  MODES = %w[day rest all].freeze
  DAY_MINUTES = 24 * 60

  attr_reader :start_hour, :end_hour, :mode

  def initialize(start_hour:, end_hour:, mode: nil)
    @start_hour = start_hour
    @end_hour = end_hour
    @mode = MODES.include?(mode.to_s) ? mode.to_s : "day"
    freeze
  end

  # Ranges of minutes that end where the next one begins, in order.
  #
  # The hours around the day hours are two ranges, or one, or none when the day
  # hours cover the whole day.
  def segments
    case mode
    when "all" then [0...DAY_MINUTES]
    when "rest" then [0...first_minute, last_minute...DAY_MINUTES].reject { |range| range.size.zero? }
    else [first_minute...last_minute]
    end
  end

  # The switch has nothing to offer when all the modes look the same.
  def modes = whole_day? ? [] : MODES

  # Where to look for the entries that are not drawn: in the hours around the
  # day hours, or, when those are what is drawn, in the day hours.
  def other = (mode == "rest") ? "day" : "rest"

  private

  def first_minute = start_hour * 60

  def last_minute = (end_hour + 1) * 60

  def whole_day? = first_minute.zero? && last_minute == DAY_MINUTES
end
