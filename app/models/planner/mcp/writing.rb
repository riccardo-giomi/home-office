# Common functionalities that tools with the ability to write share.
#
# The kinds that an agent may name (looked up in a hash, never turned into a
# class), how its field names map to the ones of the model, the limits of a
# call, and a batch in which one failing item does not stop the others.
module Planner::Mcp::Writing
  MAX_OPERATIONS = 50
  KINDS = {"event" => Planner::Event, "task" => Planner::Task, "todo" => Planner::Todo}.freeze
  PRIORITIES = Planner::Item.priorities.keys.freeze
  CLOCK = "^([01]\\d|2[0-3]):[0-5]\\d$"
  RENAMED = {start: :start_time, end: :end_time}.freeze
  FIELDS = %i[title notes priority day start end tracks_done].freeze
  DAY = /\A\d{4}-\d{2}-\d{2}\z/

  # What is wrong with the input itself, in words for the agent.
  class Invalid < StandardError; end

  # Returns the attributes of the model for the fields that an agent gave. Only
  # those given are in it.
  def self.attributes(given)
    given.slice(*FIELDS).to_h do |name, value|
      value = (value ? 1 : 0) if name == :tracks_done
      value = iso_date(value, name) if name == :day
      [RENAMED.fetch(name, name), value]
    end
  end

  def self.iso_date(value, name)
    raise Invalid, "#{name} must be an ISO 8601 date such as 2026-10-11." unless DAY.match?(value.to_s)

    Date.strptime(value.to_s, "%Y-%m-%d")
  rescue Date::Error
    raise Invalid, "#{name} must be an ISO 8601 date such as 2026-10-11."
  end

  # Returns the given fields that the kind does not let a person set.
  def self.refused_fields(klass, attributes)
    attributes.keys - klass.editable_attributes
  end

  def self.refused_message(klass, fields)
    names = fields.map { |name| RENAMED.invert.fetch(name, name) }
    allowed = klass.editable_attributes.map { |name| RENAMED.invert.fetch(name, name) }
    "A #{klass.kind} has no #{names.to_sentence}. It can take: #{allowed.join(", ")}."
  end

  def self.messages(*records) = records.flat_map { |record| record.errors.full_messages }.uniq.join("; ")

  # Runs the block for each operation on its own.
  #
  # An exception in one operaton is reported and answered, and the rest go on.
  def self.each_result(operations)
    operations.map do |operation|
      yield operation
    rescue Invalid => error
      {ref: (operation[:ref] if operation.is_a?(Hash)) || operation.to_s.first(40), ok: false, error: error.message}.compact
    rescue => error
      Rails.error.report(error, handled: true, source: "mcp")
      {ref: (operation[:ref] if operation.is_a?(Hash)) || operation.to_s.first(40), ok: false, error: "That could not be done."}.compact
    end
  end

  def self.not_found(ref) = "Not found: #{ref.to_s.first(40)}. #{Planner::ItemRef::HELP}"

  # Returns the series of an occurrence: the one that an unsaved occurrence
  # carries, or the one that a saved one points to (kept, and the user's).
  def self.series_of(user, item)
    item.new_record? ? item.series : Planner::Series.owned_by(user).kept.find(item.series_id)
  end
end
