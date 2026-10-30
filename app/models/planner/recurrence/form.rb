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
