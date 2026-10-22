# A day with an optional start and end, typed as
# local HH:MM strings.
#
# Shared by tasks and events.
module Planner::Timed
  extend ActiveSupport::Concern

  DEFAULT_DURATION = 30.minutes
  CLOCK_TIME = /\A([01]\d|2[0-3]):[0-5]\d\z/

  included do
    # Remember what the user typed in the forms so you can give it back in case
    # of error.
    attr_writer :start_time, :end_time

    before_validation :assemble_times, if: :times_given?
    before_validation :fill_end

    validates :day, presence: true
    validate :times_are_consistent
  end

  def start_time = defined?(@start_time) ? @start_time : clock_time(starts_at)

  def end_time = defined?(@end_time) ? @end_time : clock_time(ends_at)

  private

  def times_given? = defined?(@start_time) || defined?(@end_time) || (persisted? && day_changed? && starts_at.present?)

  def clock_time(instant)
    instant&.in_time_zone(time_zone)&.strftime("%H:%M") if Core::EffectivePreferences.valid_time_zone?(time_zone)
  end

  def assemble_times
    @time_errors = {}
    start = read_clock(:start_time, start_time)
    stop = read_clock(:end_time, end_time)
    if start.blank? && stop.blank?
      self.starts_at = self.ends_at = self.time_zone = nil unless @time_errors.any?
    elsif start.blank?
      @time_errors[:start_time] = :blank
    elsif day && !@time_errors.key?(:start_time)
      zone = time_zone || Time.zone.name
      self.time_zone = zone
      self.starts_at = local_instant(zone, start)
      self.ends_at = stop.present? ? local_instant(zone, stop) : nil
    end
  end

  def read_clock(attribute, value)
    return if value.blank?
    return value if CLOCK_TIME.match?(value.to_s)

    @time_errors[attribute] = :invalid
    nil
  end

  def local_instant(zone, clock) = ActiveSupport::TimeZone[zone].parse("#{day} #{clock}")

  def fill_end
    return if ends_at || !starts_at

    self.ends_at = [starts_at + DEFAULT_DURATION, end_of_start_day].compact.min
    @end_time = clock_time(ends_at) if defined?(@end_time)
  end

  # The default end never spills into the next day; one the user typed is left
  # for validation to judge.
  def end_of_start_day
    starts_at.in_time_zone(time_zone).end_of_day.change(usec: 0) if Core::EffectivePreferences.valid_time_zone?(time_zone)
  end

  def times_are_consistent
    (@time_errors || {}).each { |attribute, error| errors.add(attribute, error) }
    return if @time_errors&.any? || (starts_at.nil? && ends_at.nil?)

    errors.add(:start_time, :blank) if starts_at.nil?
    return errors.add(:time_zone, :inclusion) unless Core::EffectivePreferences.valid_time_zone?(time_zone)
    return if starts_at.nil? || ends_at.nil?

    errors.add(:end_time, :after_start) unless ends_at > starts_at
    errors.add(:end_time, :same_day) unless local_date(ends_at) == day
    errors.add(:day, :not_start_day) unless local_date(starts_at) == day
  end

  def local_date(instant) = instant.in_time_zone(time_zone).to_date
end
