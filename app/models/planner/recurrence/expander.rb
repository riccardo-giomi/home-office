# The dates a rule produces.
#
# It is the one place that knows the expansion library, and it is pure: no
# database. Another implementation has to pass the same contract
# (test/support/expander_contract.rb).
module Planner::Recurrence::Expander
  UNTIL = /;?UNTIL=(\d{8})/

  # The local dates in `between` (both ends included), ascending.
  #
  # The rule is read from the anchor at `start_time` in `time_zone` (midnight
  # when `start_time` is nil), so a wall-clock time that does not exist on a day
  # moves forward.
  def self.dates(rrule:, starts_on:, start_time:, time_zone:, between:)
    # ActiveSupport's zone moves a time that does not exist forward and takes
    # the first of a time that happens twice. TZInfo's local_time raises for
    # both, and for a midnight that is skipped.
    zone = ActiveSupport::TimeZone[time_zone] or raise ArgumentError, "unknown time zone: #{time_zone}"
    until_on = Date.strptime(rrule[UNTIL, 1], "%Y%m%d") if rrule.match?(UNTIL)
    hour, minute = start_time ? start_time.split(":").map(&:to_i) : [0, 0]
    anchor = zone.local(starts_on.year, starts_on.month, starts_on.day, hour, minute).to_time
    rule = RRule::Rule.new(rrule.sub(UNTIL, ""), dtstart: anchor, tzid: time_zone)

    from = zone.local(between.first.year, between.first.month, between.first.day).to_time
    to = zone.local(between.last.year, between.last.month, between.last.day, 23, 59, 59).to_time
    rule.between(from, to).map(&:to_date).select do |date|
      between.cover?(date) && (until_on.nil? || date <= until_on)
    end
  end
end
