# What is on the plate of the user.
#
# Events, tasks and todos, by range of days, view, state, done or not, title, or
# the trash.
class Planner::Mcp::ListItems < Core::Mcp::Tool
  Query = Planner::Mcp::ItemQuery

  tool_name "list_items"
  description "List the user's events, tasks and todos. Default: active ones in the next 14 days, then the todos. " \
    "view overrides the day range with the important, missed or forgotten list; trashed lists the trash. Use get_item for whole notes and links."
  access :read
  input_schema(
    properties: {
      type: {type: "string", enum: Query::TYPES, description: "Only this kind."},
      from: {type: "string", description: "First day, ISO 8601 (default today). Not used for todos."},
      to: {type: "string", description: "Last day, ISO 8601 (default 13 days after from; at most 366 days in all)."},
      view: {type: "string", enum: Query::VIEWS, description: "important: urgent events ahead; missed: events to tick that are past; forgotten: open tasks that are past."},
      state: {type: "string", enum: Query::STATES, description: "Default active."},
      done: {type: "boolean", description: "true: only done; false: only not done."},
      q: {type: "string", description: "Part of the title."},
      trashed: {type: "boolean", description: "List the trash (newest first; a trashed series is one entry, named s<id>)."},
      limit: {type: "integer", minimum: 1, maximum: Query::MAX_LIMIT, description: "Default 50."},
      offset: {type: "integer", minimum: 0}
    },
    additionalProperties: false
  )

  def self.call(server_context:, **arguments)
    user = server_context[:user]
    page = Query.new(user, today: Date.current, **arguments).page
    rows = page.entries.grep(Planner::Item)
    counts = Planner::Mcp::ItemPresenter.link_counts(rows.reject(&:new_record?).map(&:id))
    items = page.entries.map do |entry|
      if entry.is_a?(Planner::Item)
        Planner::Mcp::ItemPresenter.new(entry, links: counts[entry.id], trashed: page.trashed).to_h
      else
        Planner::Mcp::ItemPresenter.trashed_series(entry)
      end
    end
    more = arguments.fetch(:offset, 0) + items.size < page.total
    respond(time_zone: Time.zone.name, total: page.total, more: (true if more), items:)
  rescue Query::Invalid => error
    fail(error.message)
  end
end
