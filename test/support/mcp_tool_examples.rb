# What every MCP tool that names an item by ref shares: another user's, trashed and made-up refs are "not found" and
# nothing of theirs changes; a read-only token does not have the tool. The including test defines `tool` (the name),
# `arguments_for(ref)` and `changed?` (whether anything of the other user's changed).
module McpToolExamples
  def self.included(base)
    base.class_eval do
      it "does not touch what belongs to another user, and says it was not found" do
        ref = planner_items(:other_users_task).id.to_s
        before = Planner::Item.where.not(user_id: users(:admin).id).pluck(:id, :title, :state, :updated_at)
        links_before = Core::Link.where.not(user_id: users(:admin).id).order(:id).pluck(:id, :first_entity_id, :second_entity_id)
        call_tool("admin_write", tool, arguments_for(ref))
        assert_match(/not found/i, result_text)
        assert_equal before, Planner::Item.where.not(user_id: users(:admin).id).pluck(:id, :title, :state, :updated_at)
        assert_equal links_before, Core::Link.where.not(user_id: users(:admin).id).order(:id).pluck(:id, :first_entity_id, :second_entity_id)
        assert Core::Entity.kept.exists?(id: ref), "the other user's entity was trashed"
        assert_empty Core::Link.where(user_id: users(:admin).id).involving([ref]), "a link was made to the other user's record"
      end

      it "says a made-up ref was not found, and how to name one" do
        call_tool("admin_write", tool, arguments_for("999999999"))
        assert_match(/not found/i, result_text)
        call_tool("admin_write", tool, arguments_for("not a ref"))
        assert_match(/not found/i, result_text)
      end

      it "is not a tool a read-only token has" do
        refute_includes tool_names("member_read"), tool
        call_tool("member_read", tool, arguments_for(planner_items(:pay_rent_task).id.to_s))
        assert_match(/Tool not found/, rpc_body.dig("error", "data"))
      end
    end
  end

  # The text of the single result of a batch, or of an error
  def result_text
    return rpc_body.dig("error", "data").to_s if rpc_body["error"]

    rpc_body.dig("result", "content", 0, "text").to_s
  end
end
