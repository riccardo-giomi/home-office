# What the Repeat fields of the event form send (`repeat[...]`), as strings.
#
# It turns them into a Rule for an anchor day. The form is a plain model, so the
# fields, the labels and the error messages work like any other.
class Planner::Recurrence::Form
  include ActiveModel::Model
  include ActiveModel::Attributes

  attribute :frequency, :string, default: "never"
  attribute :interval, :integer, default: 1
  attribute :weekdays, default: -> { [] }
  attribute :monthly, :string, default: "day"
  attribute :ends, :string, default: "never"
  attribute :until_on, :date
  attribute :count, :integer

  def self.model_name = ActiveModel::Name.new(self, nil, "Repeat")

  # Creates a new form from the given recurrence rule.
  def self.from_rule(rule)
    ends = if rule.until_on then "until"
    elsif rule.count then "count"
    else "never"
    end
    new(frequency: rule.frequency, interval: rule.interval, weekdays: rule.weekdays, monthly: (rule.nth_weekday ? "weekday" : "day"),
      ends:, until_on: rule.until_on, count: rule.count)
  end

  # What the fields say about the recurrence rule.
  #
  # What does not matter for the frequency chosen is left out, because a hidden
  # field still sends its value.
  def signature
    {frequency:, interval:, weekdays: (Array(weekdays).compact_blank.sort if frequency == "weekly"), monthly: (monthly if frequency == "monthly"),
     ends:, until_on: (until_on if ends == "until"), count: (count if ends == "count")}
  end

  def same_rule_as?(other) = signature == other.signature

  def repeating? = frequency.present? && frequency != "never"

  # The rule these fields describe for an event on `anchor`.
  #
  # It is nil when the fields do not repeat, or when they are wrong (see
  # `errors`).
  def rule_for(anchor)
    errors.clear
    return unless repeating?

    check_ends(anchor)
    errors.add(:interval, :out_of_range) unless Planner::Recurrence::Rule::INTERVALS.cover?(interval)
    return if errors.any?

    rule = Planner::Recurrence::Rule.for_anchor(anchor, frequency:, interval:, weekdays: (Array(weekdays).compact_blank if frequency == "weekly"), monthly:,
      until_on: (until_on if ends == "until"), count: (count if ends == "count"))
    rule.errors.each { |attribute| errors.add(RULE_ERRORS.fetch(attribute, :frequency), (attribute == :weekdays) ? :blank : :invalid) }
    rule if errors.empty?
  end

  private

  RULE_ERRORS = {frequency: :frequency, weekdays: :weekdays, interval: :interval, count: :count}.freeze

  def check_ends(anchor)
    case ends
    when "until"
      errors.add(:until_on, until_on ? :before_start : :blank) if until_on.nil? || until_on < anchor
    when "count"
      errors.add(:count, :out_of_range) unless Planner::Recurrence::Rule::COUNTS.cover?(count)
    end
  end
end
