# One item whole: its notes in full, its series and its links.
class Planner::Mcp::GetItem < Core::Mcp::Tool
  tool_name "get_item"
  description "Get one event, task or todo with its whole notes, its series (if it repeats) and its links. ref: an item id such as 123, or s7@2026-11-03 for one occurrence of a repeating event."
  access :read
  input_schema(properties: {ref: {type: "string"}}, required: ["ref"], additionalProperties: false)

  def self.call(ref:, server_context:)
    user = server_context[:user]
    item = Planner::ItemRef.resolve(user, ref) or return fail(Planner::Mcp::Writing.not_found(ref))
    series = Planner::Mcp::Writing.series_of(user, item) if item.occurrence?
    data = Planner::Mcp::ItemPresenter.new(item, full: true, series:).to_h
    respond(data.merge(links: (links_of(item) if item.persisted?)))
  end

  def self.links_of(item)
    Core::LinkIndex.new(item.id).ends_of(item.id).map do |link_end|
      {id: link_end.entity.id.to_s, type: link_end.kind_key, title: link_end.label, trashed: (true if link_end.trashed?)}.compact
    end.presence
  end
end
