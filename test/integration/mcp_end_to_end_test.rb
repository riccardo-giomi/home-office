require "test_helper"

# What an agent does in a day, over the endpoint, from the first call: a write token plans and tidies, a read-only token
# can look at all of it and change none of it
class McpEndToEndTest < ActionDispatch::IntegrationTest
  include McpTokens

  let(:member) { users(:member) }

  before { travel_to Time.utc(2026, 10, 7, 12, 0, 0) }

  def call(token, name, arguments = {})
    post mcp_path, params: {jsonrpc: "2.0", id: 1, method: "tools/call", params: {name:, arguments:}}.to_json,
      headers: {"Content-Type" => "application/json", "Accept" => "application/json"}.merge(bearer(token))
    assert_response :success
    body = JSON.parse(response.body)
    return {"refused" => body.dig("error", "data")} if body["error"]

    JSON.parse(body.dig("result", "content", 0, "text"))
  end

  it "plans, edits, tidies and links, and a read-only token sees it all and changes nothing" do
    todo = call("member_write", "create_item", {type: "todo", title: "Book the train", priority: "high"})
    series = call("member_write", "create_item", {type: "event", title: "Standup", day: "2026-10-12", start: "09:30", end: "09:45",
                                                  repeat: {frequency: "weekly", weekdays: %w[MO TU WE TH FR]}})
    deadline = call("member_write", "create_item", {type: "task", title: "Send the report", day: "2026-10-09"})

    week = call("member_write", "list_items", {from: "2026-10-07", to: "2026-10-16"})
    assert_equal ["Send the report"] + ["Standup"] * 5 + ["Book the train"], week["items"].map { |item| item["title"] }
    occurrence = series["next"].first

    assert_equal true, call("member_write", "update_items", {changes: [{ref: occurrence, title: "Standup (long)", end: "10:15"}]})["results"].first["ok"]
    assert_equal true, call("member_write", "update_items", {changes: [{ref: deadline["id"], done: true}]})["results"].first["ok"]
    call("member_write", "link_items", {pairs: [[occurrence, deadline["id"]], [todo["id"], deadline["id"]]]})
    detail = call("member_write", "get_item", {ref: occurrence})
    assert_equal ["Standup (long)", "10:15", 1], [detail["title"], detail["end"], detail["links"].size]

    assert_equal true, call("member_write", "trash_items", {refs: [todo["id"]]})["results"].first["ok"]
    assert_equal ["Book the train"], call("member_write", "list_items", {trashed: true})["items"].map { |item| item["title"] }
    assert_equal true, call("member_write", "restore_items", {refs: [todo["id"]]})["results"].first["ok"]

    status = call("member_read", "overview")
    assert_equal "2026-10-07", status["today"]
    assert_equal call("member_write", "list_items", {from: "2026-10-07", to: "2026-10-16"}), call("member_read", "list_items", {from: "2026-10-07", to: "2026-10-16"})
    assert_equal detail, call("member_read", "get_item", {ref: occurrence})

    before = [Planner::Item.count, Planner::Series.count, Core::Link.count, Core::Entity.trashed.count]
    {"create_item" => {type: "todo", title: "No"}, "update_items" => {changes: [{ref: todo["id"], title: "No"}]}, "trash_items" => {refs: [todo["id"]]},
     "restore_items" => {refs: [todo["id"]]}, "link_items" => {pairs: [[todo["id"], deadline["id"]]]}, "unlink_items" => {pairs: [[todo["id"], deadline["id"]]]}}.each do |tool, arguments|
      assert_match(/Tool not found/, call("member_read", tool, arguments)["refused"], tool)
    end
    assert_equal before, [Planner::Item.count, Planner::Series.count, Core::Link.count, Core::Entity.trashed.count]
    assert_equal "Book the train", Planner::Todo.find(todo["id"]).title
  end
end
