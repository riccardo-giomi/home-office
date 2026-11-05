require "test_helper"

class McpRefreshTest < ActionDispatch::IntegrationTest
  include McpHelpers

  let(:admin) { users(:admin) }

  # How many refresh messages the open home pages of the user receive.
  def messages_during(user = admin, &) = capture_turbo_stream_broadcasts(Core::Overview.stream(user.id), &).size

  def succeeded
    assert_nil rpc_body["error"], rpc_body.inspect
    refute rpc_body.dig("result", "isError"), rpc_body.dig("result", "content", 0, "text")
  end

  it "sends one message when a tool makes something that is counted" do
    count = messages_during { call_tool("admin_write", "create_item", {type: "todo", title: "Water the ferns"}) }
    succeeded
    assert_equal 1, count
  end

  it "sends one message when a tool changes what is counted, and none for what is not" do
    ref = planner_items(:water_plants_todo).id.to_s
    assert_equal 1, messages_during { call_tool("admin_write", "update_items", {changes: [{ref:, priority: "urgent"}]}) }
    succeeded
    assert_equal 0, messages_during { call_tool("admin_write", "update_items", {changes: [{ref:, title: "Water the ferns"}]}) }
    succeeded
  end

  it "sends one message when a tool moves an item to the trash and when it brings it back" do
    ref = planner_items(:buy_stamps_task).id.to_s
    assert_equal 1, messages_during { call_tool("admin_write", "trash_items", {refs: [ref]}) }
    succeeded
    assert_equal 1, messages_during { call_tool("admin_write", "restore_items", {refs: [ref]}) }
    succeeded
  end

  it "sends a message when a tool trashes a whole series, which is a bulk write" do
    series = Planner::Series.create!(user: admin, title: "Gym", starts_on: Date.current, time_zone: "UTC", rrule: "FREQ=DAILY")
    count = messages_during { call_tool("admin_write", "trash_items", {refs: ["s#{series.id}@#{Date.current.iso8601}"], scope: "all"}) }
    succeeded
    assert_operator count, :>=, 1
  end

  it "sends nothing when a tool only reads, and nothing to another user" do
    assert_equal 0, messages_during { call_tool("admin_write", "overview") }
    succeeded
    assert_equal 0, messages_during(users(:member)) { call_tool("admin_write", "create_item", {type: "todo", title: "Mine"}) }
  end
end
