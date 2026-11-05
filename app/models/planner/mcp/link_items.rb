# Links pairs of items of any kind.
#
# An occurrence that is only a date is saved first, as the controllers do.
class Planner::Mcp::LinkItems < Core::Mcp::Tool
  Writing = Planner::Mcp::Writing

  tool_name "link_items"
  description "Link up to #{Writing::MAX_OPERATIONS} pairs of items. A link has no direction and no data; linking again changes nothing. A pair is two refs: item ids, or s<series id>@YYYY-MM-DD."
  access :write
  input_schema(
    properties: {pairs: {type: "array", minItems: 1, maxItems: Writing::MAX_OPERATIONS, items: {type: "array", minItems: 2, maxItems: 2, items: {type: "string"}}}},
    required: ["pairs"],
    additionalProperties: false
  )

  def self.call(pairs:, server_context:)
    user = server_context[:user]
    respond(results: Writing.each_result(pairs.map { |pair| {ref: pair.join(" + "), pair:} }) { |operation| link_one(user, operation) })
  end

  def self.link_one(user, operation)
    first_ref, second_ref = operation.fetch(:pair)
    ends = [first_ref, second_ref].map { |ref| Planner::ItemRef.resolve(user, ref) or return {pair: operation[:pair], ok: false, error: Writing.not_found(ref)} }
    first, second = ends.map { |item| item.new_record? ? item.series.materialize(item.occurrence_on) : item }
    link = Core::Link.connect(user, first.id, second.id)
    return {pair: operation[:pair], ok: false, error: Writing.messages(link)} unless link.persisted?

    {pair: operation[:pair], ok: true, linked: link.previously_new_record? ? "created" : "already"}
  end
end
