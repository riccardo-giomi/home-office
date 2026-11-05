# Takes items out of the trash, as they were.
#
# A trashed series is named s<id>, as `list_items` gives it.
class Planner::Mcp::RestoreItems < Core::Mcp::Tool
  Writing = Planner::Mcp::Writing

  tool_name "restore_items"
  description "Take up to #{Writing::MAX_OPERATIONS} items out of the trash. refs: item ids, or s<series id> for a trashed series, as list_items trashed gives them."
  access :write
  input_schema(
    properties: {refs: {type: "array", minItems: 1, maxItems: Writing::MAX_OPERATIONS, items: {type: "string"}}},
    required: ["refs"],
    additionalProperties: false
  )

  def self.call(refs:, server_context:)
    user = server_context[:user]
    respond(results: Writing.each_result(refs) { |ref| restore_one(user, ref) })
  end

  def self.restore_one(user, ref)
    text = ref.to_s.strip
    found = if (match = /\As(\d+)\z/.match(text))
      Planner::Series.owned_by(user).trashed.find_by(id: match[1].to_i)&.tap(&:restore_group)
    elsif /\A[1-9]\d*\z/.match?(text)
      Planner::Item.owned_by(user).trashed.includes(:entity).find_by(id: text.to_i)&.tap(&:restore)
    end
    found ? {ref:, ok: true} : {ref:, ok: false, error: "Not found in the trash: #{text.first(40)}. Ask list_items with trashed: true for what is there."}
  end
end
