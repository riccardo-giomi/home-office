# Makes an event, a task or a todo.
#
# An event with repeat fields makes a series instead.
class Planner::Mcp::CreateItem < Core::Mcp::Tool
  Writing = Planner::Mcp::Writing

  tool_name "create_item"
  description "Create an event, task or todo. day defaults to today (events and tasks); start and end are local HH:MM (end defaults to start + 30 minutes). " \
    "An event with repeat makes a repeating series: you get its id (s<id>) and the next dates."
  access :write
  input_schema(
    properties: {
      type: {type: "string", enum: Writing::KINDS.keys},
      title: {type: "string", maxLength: 255},
      notes: {type: "string"},
      priority: {type: "string", enum: Writing::PRIORITIES, description: "Default normal."},
      day: {type: "string", description: "ISO 8601 date. Not for todos."},
      start: {type: "string", pattern: Writing::CLOCK},
      end: {type: "string", pattern: Writing::CLOCK},
      tracks_done: {type: "boolean", description: "Events only: give it a done box."},
      repeat: {
        type: "object", description: "Events only.", required: ["frequency"], additionalProperties: false,
        properties: {
          frequency: {type: "string", enum: Planner::Recurrence::Rule::FREQUENCIES},
          interval: {type: "integer", minimum: 1, maximum: 99, description: "Every n days, weeks, months or years. Default 1."},
          weekdays: {type: "array", items: {type: "string", enum: Planner::Recurrence::Rule::WEEKDAYS}, description: "Weekly: default the day's weekday."},
          monthly: {type: "string", enum: %w[day weekday], description: "Monthly: on the day of the month (default) or on the nth weekday."},
          ends: {type: "string", enum: %w[never until count], description: "Default never."},
          until_on: {type: "string", description: "ISO 8601 date, for ends until."},
          count: {type: "integer", minimum: 1, maximum: 999, description: "For ends count."}
        }
      }
    },
    required: %w[type title],
    additionalProperties: false
  )

  def self.call(type:, title:, server_context:, repeat: nil, **fields)
    user = server_context[:user]
    klass = Writing::KINDS.fetch(type)
    return fail("Only events repeat.") if repeat && klass != Planner::Event

    attributes = Writing.attributes(fields.merge(title:))
    refused = Writing.refused_fields(klass, attributes)
    return fail(Writing.refused_message(klass, refused)) if refused.any?

    item = klass.new(attributes.merge(user:))
    item.day ||= Date.current if item.timed?
    repeat ? create_series(item, repeat) : create_item(item)
  rescue Writing::Invalid => error
    fail(error.message)
  end

  def self.create_item(item)
    return respond(Planner::Mcp::ItemPresenter.new(item).to_h.merge(ok: true)) if item.save

    fail(Writing.messages(item))
  end

  # Makes a series from an event with repeat fields.
  #
  # A series that starts long ago would turn every occurrence since then into an
  # event at the next catch-up, so the start is at most a year back.
  def self.create_series(event, repeat)
    earliest = Date.current - 1.year
    return fail("A repeating event cannot start more than a year ago (the earliest day is #{earliest.iso8601}).") if event.day && event.day < earliest

    form = Planner::Recurrence::Form.new(**repeat)
    series = Planner::Recurrence::Create.new(event:, form:).call or return fail(Writing.messages(event, form))
    respond(ok: true, series: "s#{series.id}", repeat: series.rule.summary, next: next_occurrences(series, event.day))
  end

  # Returns the names of the first three occurrences.
  #
  # It looks a year ahead and, for a rule that is rarely due, eleven.
  def self.next_occurrences(series, day)
    dates = [400, 4000].lazy.map { |days| series.dates(day..(day + days)).first(3) }.find { |found| found.size == 3 } || series.dates(day..(day + 4000)).first(3)
    dates.map { |date| "s#{series.id}@#{date.iso8601}" }
  end
end
