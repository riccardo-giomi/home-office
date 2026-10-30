# An event that repeats.
#
# It holds the template of the occurrences, the rule that gives their dates and
# the span that limits them (`starts_on`, `from_on`, `ends_on`). It is not an
# entity and cannot be linked: its occurrences are events, saved when someone
# touches them (see Planner::Series::Occurrences).
#
# A series split by "this and following" becomes a chain of parts that share the
# `chain_id` of the first. "All events" means every part of the chain.
class Planner::Series < ApplicationRecord
  include Core::SoftDeletable

  belongs_to :user
  has_many :events, class_name: "Planner::Event", foreign_key: :series_id, inverse_of: :series, dependent: nil
  has_many :exclusions, class_name: "Planner::SeriesExclusion", foreign_key: :series_id, inverse_of: :series, dependent: nil

  enum :priority, {low: 0, normal: 1, high: 2, urgent: 3}, default: :normal, validate: true

  normalizes :title, with: ->(title) { title.strip }

  validates :title, presence: true, length: {maximum: 255}
  validates :tracks_done, inclusion: {in: [0, 1]}
  validates :starts_on, presence: true
  validates :time_zone, inclusion: {in: ->(_) { Core::EffectivePreferences::ZONES }}
  validates :start_time, format: {with: Planner::Timed::CLOCK_TIME}, allow_nil: true
  validates :start_time, presence: true, if: :duration_minutes?
  validates :duration_minutes, presence: true, numericality: {only_integer: true, greater_than: 0}, if: :start_time?
  validate :rule_is_offered
  validate :span_is_ordered
  validate :ends_the_same_day

  include Planner::Series::Occurrences

  scope :owned_by, ->(user) { where(user:) }

  def self.table_name = "planner_series"

  # What one action sent to the trash, shown as one row of the trash page.
  #
  # It is the parts of a chain that share one `deleted_at`, the earliest first.
  TrashGroup = Data.define(:segments) do
    def first = segments.first

    def deleted_at = first.deleted_at

    # The id of the first part of the group.
    #
    # It stands for the whole group in the restore address and in the id of its
    # row: `restore_group` finds the other parts from it.
    def id = first.id
  end

  # The trashed series of the user as groups, newest first.
  def self.trash_groups(user)
    trashed.owned_by(user).order(:starts_on, :id).to_a
      .group_by { |part| [part.chain_key, part.deleted_at] }.values
      .map { |segments| TrashGroup.new(segments) }
      .sort_by { |group| -group.deleted_at.to_f }
  end

  # Takes the series away for good.
  #
  # Its events that are in the trash are deleted. The others stay as events of
  # their own, no longer part of the series. Then the series is deleted, and its
  # skipped dates with it.
  def self.purge(series)
    ids = series.pluck(:id)
    return if ids.empty?

    transaction { purge_ids(ids) }
  end

  # When the first part of a chain goes, the next remaining part becomes the
  # first: it gets no `chain_id`, and the others point to it.
  def self.purge_ids(ids)
    where(id: ids, chain_id: nil).pluck(:id).each do |root|
      head, *rest = where(chain_id: root).where.not(id: ids).order(:starts_on, :id).to_a
      next unless head

      where(id: head.id).update_all(chain_id: nil)
      where(id: rest.map(&:id)).update_all(chain_id: head.id) if rest.any?
    end
    Core::Entity.where(id: Planner::Item.where(series_id: ids).select(:id)).where.not(deleted_at: nil).delete_all
    Planner::Item.where(series_id: ids).update_all(series_id: nil, occurrence_on: nil)
    where(id: ids).delete_all
  end

  # Purges the series that sat in the trash past their time.
  def self.purge_expired(now = Time.current) = purge(purgeable(now))

  # Builds a series from an event that is valid but not saved, and a rule.
  #
  # The event is the template and gives the first day. An all-day event has no
  # time zone, so the series takes the user's time zone for the request.
  def self.from_event(event, rule)
    timed = event.starts_at && event.ends_at
    new(
      user_id: event.user_id, title: event.title, notes: event.notes, priority: event.priority,
      tracks_done: event.tracks_done, starts_on: event.day,
      time_zone: event.time_zone || Time.zone.name,
      start_time: (event.start_time if timed),
      duration_minutes: (((event.ends_at - event.starts_at) / 60).to_i if timed),
      rrule: rule.to_rrule
    )
  end

  # The rule the stored text says, or nil when the text is not one of the
  # offered rules.
  def rule = Planner::Recurrence::Rule.parse(rrule)

  def rule=(rule)
    self.rrule = rule.to_rrule
  end

  # Takes the whole group out of the trash: the parts of the chain that were
  # trashed by the same action, and the events trashed at that moment. An event
  # trashed earlier stays in the trash.
  def restore_group
    group = self.class.where(user_id:, deleted_at:).where("id = :key OR chain_id = :key", key: chain_key)
    self.class.transaction do
      Core::Entity.where(id: Planner::Item.where(series_id: group.select(:id)).select(:id), deleted_at:)
        .update_all(deleted_at: nil)
      group.update_all(deleted_at: nil)
    end
  end

  def tracks_done? = tracks_done == 1

  # The `chain_id` of a part, or its own id when it is the first part. A series
  # that was never split is a chain of one.
  def chain_key = chain_id || id

  # Every part of the chain, earliest first.
  def chain
    self.class.where(user_id:, id: chain_key).or(self.class.where(user_id:, chain_id: chain_key))
      .order(:starts_on, :id).to_a
  end

  private

  def rule_is_offered
    errors.add(:rrule, :invalid) unless rule
  end

  # The time of day plus the duration must end before midnight, as for an event
  # (Planner::Timed).
  def ends_the_same_day
    return unless start_time&.match?(Planner::Timed::CLOCK_TIME) && duration_minutes.is_a?(Integer)

    hours, minutes = start_time.split(":").map(&:to_i)
    errors.add(:duration_minutes, :same_day) if (hours * 60) + minutes + duration_minutes > 24 * 60
  end

  def span_is_ordered
    errors.add(:ends_on, :before_start) if ends_on && starts_on && ends_on < starts_on
    errors.add(:from_on, :before_start) if from_on && starts_on && from_on < starts_on
    errors.add(:from_on, :after_end) if from_on && ends_on && starts_on && from_on > ends_on && ends_on >= starts_on
  end
end
