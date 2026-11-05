# Removes the links between pairs of items.
#
# There is no confirmation and no trash: a link is a row with no data.
class Planner::Mcp::UnlinkItems < Core::Mcp::Tool
  Writing = Planner::Mcp::Writing

  tool_name "unlink_items"
  description "Remove the link between up to #{Writing::MAX_OPERATIONS} pairs of items (ids; a thing in the trash can be unlinked too). Pairs that were not linked are reported, not errors."
  access :write
  input_schema(
    properties: {pairs: {type: "array", minItems: 1, maxItems: Writing::MAX_OPERATIONS, items: {type: "array", minItems: 2, maxItems: 2, items: {type: "string"}}}},
    required: ["pairs"],
    additionalProperties: false
  )

  def self.call(pairs:, server_context:)
    user = server_context[:user]
    respond(results: Writing.each_result(pairs.map { |pair| {ref: pair.join(" + "), pair:} }) { |operation| unlink_one(user, operation) })
  end

  # Links join entities, so the ends are entity ids (the same numbers as the ids
  # of the items). A date that was never saved has none.
  def self.unlink_one(user, operation)
    first_ref, second_ref = operation.fetch(:pair)
    ids = [first_ref, second_ref].map { |ref| entity_id(user, ref) or return {pair: operation[:pair], ok: false, error: Writing.not_found(ref)} }
    link = Core::Link.existing(user.id, *ids) unless ids.include?(:unsaved)
    link&.destroy!
    {pair: operation[:pair], ok: true, unlinked: link ? "removed" : "not linked"}
  end

  def self.entity_id(user, ref)
    text = ref.to_s.strip
    return :unsaved if Planner::ItemRef::OCCURRENCE.match?(text) && Planner::ItemRef.resolve(user, text)&.new_record?
    return Core::Entity.where(user_id: user.id).find_by(id: text.to_i)&.id if /\A[1-9]\d*\z/.match?(text)

    Planner::ItemRef.resolve(user, text)&.id
  end
end
