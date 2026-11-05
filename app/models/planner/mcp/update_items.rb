# Changes events, tasks and todos: fields, done and state.
#
# For an occurrence of a repeating event, the scope "this" (the default) changes
# that occurrence, saving it first if it was only a date. The scope "all"
# changes the series (title, notes, priority, times) and every occurrence that
# is already saved, but only the fields given: a saved occurrence keeps the
# others.
class Planner::Mcp::UpdateItems < Core::Mcp::Tool
  Writing = Planner::Mcp::Writing

  tool_name "update_items"
  description "Change up to #{Writing::MAX_OPERATIONS} items at once; each change is separate, and the answer lists which worked. Give only the fields to change. " \
    "scope all (an occurrence of a repeating event) changes every occurrence: not the day, done or state. The repeat rule cannot be changed."
  access :write
  input_schema(
    properties: {
      changes: {
        type: "array", minItems: 1, maxItems: Writing::MAX_OPERATIONS,
        items: {
          type: "object", required: ["ref"], additionalProperties: false,
          properties: {
            ref: {type: "string", description: "Item id, or s<series id>@YYYY-MM-DD for one occurrence."},
            scope: {type: "string", enum: %w[this all], description: "Default this."},
            title: {type: "string", maxLength: 255},
            notes: {type: "string"},
            priority: {type: "string", enum: Writing::PRIORITIES},
            day: {type: "string", description: "ISO 8601 date."},
            start: {type: "string", pattern: "#{Writing::CLOCK}|^$", description: "Local HH:MM; empty (with an empty end) makes it all-day."},
            end: {type: "string", pattern: "#{Writing::CLOCK}|^$"},
            tracks_done: {type: "boolean"},
            done: {type: "boolean", description: "Tick or untick."},
            state: {type: "string", enum: Planner::Item::STATE_CHANGES.keys, description: "active (reopen), abandoned (tasks, events), cancelled (events)."}
          }
        }
      }
    },
    required: ["changes"],
    additionalProperties: false
  )

  def self.call(changes:, server_context:)
    user = server_context[:user]
    respond(results: Writing.each_result(changes) { |change| change_one(user, change) })
  end

  def self.change_one(user, change)
    ref = change.fetch(:ref)
    item = Planner::ItemRef.resolve(user, ref) or return failed(ref, Writing.not_found(ref))
    scope = change.fetch(:scope, "this")
    attributes = Writing.attributes(change)
    refused = Writing.refused_fields(item.class, attributes)
    return failed(ref, Writing.refused_message(item.class, refused)) if refused.any?
    return failed(ref, "scope all is for occurrences of a repeating event; this item is not one.") if scope == "all" && !item.occurrence?
    return change_series(user, ref, item, change, attributes) if scope == "all"

    change_item(ref, item, change, attributes)
  end

  def self.change_item(ref, item, change, attributes)
    problem = nil
    saved = Planner::ItemRef.changing(item) do |target|
      item = target
      problem = apply(target, change, attributes)
      problem.nil? && target.save
    end
    return failed(ref, problem) if problem
    return failed(ref, Writing.messages(item)) unless saved

    {ref:, ok: true}.merge(Planner::Mcp::ItemPresenter.new(item).to_h)
  end

  # Assigns the fields. Done and state go through the rules of the item.
  #
  # Returns nil, or a text that gives the reason the change cannot be made.
  def self.apply(target, change, attributes)
    return "Set done and state in separate changes." if change.key?(:done) && change.key?(:state)

    if change.key?(:state) && change[:state] != target.state
      return "A #{target.class.kind} that is #{target.state} can become: #{target.state_changes.join(", ").presence || "nothing"}." unless target.state_changes.include?(change[:state])

      attributes = attributes.merge(state: change[:state])
    end
    if change.key?(:done)
      return "This #{target.class.kind} has no done box (set tracks_done first)." unless target.tracks_done? || attributes[:tracks_done] == 1
      return "Only an active #{target.class.kind} can be ticked." unless target.active? || attributes[:state] == "active"

      target.assign_attributes(attributes)
      target.mark_done(change[:done])
      return
    end
    target.assign_attributes(attributes)
    nil
  end

  def self.change_series(user, ref, item, change, attributes)
    return failed(ref, "The day cannot change for all occurrences; change one occurrence (scope this).") if change.key?(:day)
    return failed(ref, "done and state belong to one occurrence; use scope this.") if change.key?(:done) || change.key?(:state)

    series = Writing.series_of(user, item)
    form = Planner::Recurrence::Form.from_rule(series.rule)
    return failed(ref, Writing.messages(item, form)) unless Planner::Recurrence::Edit.new(series:, item:, scope: "all", attributes:, form:).call

    {ref:, ok: true, series: "s#{series.id}"}
  end

  def self.failed(ref, message) = {ref:, ok: false, error: message}
end
