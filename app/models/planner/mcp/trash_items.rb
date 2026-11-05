# Moves items to the trash. It never deletes.
#
# For an occurrence of a repeating event, the scope "this" skips that date and
# "all" trashes the series.
class Planner::Mcp::TrashItems < Core::Mcp::Tool
  Writing = Planner::Mcp::Writing

  tool_name "trash_items"
  description "Move up to #{Writing::MAX_OPERATIONS} items to the trash; they can be restored. For an occurrence of a repeating event, scope this (default) skips that date and all trashes the whole series."
  access :write
  input_schema(
    properties: {
      refs: {type: "array", minItems: 1, maxItems: Writing::MAX_OPERATIONS, items: {type: "string"}, description: "Item ids, or s<series id>@YYYY-MM-DD."},
      scope: {type: "string", enum: %w[this all], description: "Default this."}
    },
    required: ["refs"],
    additionalProperties: false
  )

  def self.call(refs:, server_context:, scope: "this")
    user = server_context[:user]
    respond(results: Writing.each_result(refs) { |ref| trash_one(user, ref, scope) })
  end

  def self.trash_one(user, ref, scope)
    item = Planner::ItemRef.resolve(user, ref) or return {ref:, ok: false, error: Writing.not_found(ref)}
    if item.occurrence?
      series = Writing.series_of(user, item)
      return {ref:, ok: false, error: Writing.messages(item)} unless Planner::Recurrence::Delete.new(series:, item:, scope:).call
    else
      item.trash
    end
    {ref:, ok: true}
  end
end
