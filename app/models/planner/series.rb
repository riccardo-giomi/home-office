# An event that repeats.
#
# It holds the template of the occurrences, the rule and the span in which they
# show. It is not an entity and cannot be linked: its occurrences are events,
# made when someone touches them (see Planner::Series::Occurrences).
#
# A series split in two keeps one `chain_id`, and "all events" means the whole
# chain.
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

  scope :owned_by, ->(user) { where(user:) }

  def self.table_name = "planner_series"

  def rule = Planner::Recurrence::Rule.parse(rrule)

  def rule=(rule)
    self.rrule = rule.to_rrule
  end

  def tracks_done? = tracks_done == 1

  # The first part's id names the chain. A series that was never split is its
  # own chain.
  def chain_key = chain_id || id

  def chain
    self.class.where(user_id:, id: chain_key).or(self.class.where(user_id:, chain_id: chain_key))
      .order(:starts_on, :id).to_a
  end

  private

  def rule_is_offered
    errors.add(:rrule, :invalid) unless rule
  end

  # Planner::Timed asks the same of an event: it cannot run past midnight.
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
