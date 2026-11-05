require "test_helper"

class McpLinkToolsTest < ActionDispatch::IntegrationTest
  include McpHelpers

  let(:admin) { users(:admin) }
  let(:stamps) { planner_items(:buy_stamps_task) }
  let(:attic) { planner_items(:abandoned_task) }
  let(:plants) { planner_items(:water_plants_todo) }

  before { travel_to Time.utc(2026, 10, 7, 12, 0, 0) }

  def run_tool(tool, arguments)
    call_tool("admin_write", tool, arguments)
    assert_nil rpc_body["error"], rpc_body["error"].inspect
    tool_data.fetch("results")
  end

  def link(*pairs) = run_tool("link_items", pairs:)

  def unlink(*pairs) = run_tool("unlink_items", pairs:)

  def linked?(first, second) = Core::Link.existing(admin.id, first.id, second.id).present?

  def weekly_series
    Planner::Series.create!(user: admin, title: "Gym", starts_on: Date.new(2026, 10, 12), time_zone: "UTC", rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "18:00", duration_minutes: 60)
  end

  describe "link_items" do
    let(:tool) { "link_items" }
    include McpToolExamples

    def arguments_for(ref) = {pairs: [[ref, stamps.id.to_s]]}

    it "links two items, whatever their kinds, and says so" do
      result = link([stamps.id.to_s, plants.id.to_s]).first
      assert_equal [true, "created"], [result["ok"], result["linked"]]
      assert linked?(stamps, plants)
      assert_equal 1, Core::Link.where(user_id: admin.id).involving([stamps.id]).where(first_entity_id: [stamps.id, plants.id], second_entity_id: [stamps.id, plants.id]).count
    end

    it "does not link twice, in either order" do
      link([stamps.id.to_s, plants.id.to_s])
      assert_no_difference -> { Core::Link.count } do
        assert_equal "already", link([plants.id.to_s, stamps.id.to_s]).first["linked"]
      end
    end

    it "does several pairs at once: the good ones are made, the bad ones say why" do
      results = link([stamps.id.to_s, plants.id.to_s], [stamps.id.to_s, stamps.id.to_s], [stamps.id.to_s, "999999"], [attic.id.to_s, plants.id.to_s])
      assert_equal [true, false, false, true], results.map { |result| result["ok"] }
      assert_match(/itself/i, results[1]["error"])
      assert_match(/not found/i, results[2]["error"])
      assert linked?(attic, plants)
    end

    it "does not link to a thing in the trash" do
      result = link([stamps.id.to_s, planner_items(:trashed_event).id.to_s]).first
      assert_equal false, result["ok"]
      assert_match(/not found/i, result["error"])
    end

    it "saves an occurrence that is only a date, once, to link it" do
      series = weekly_series
      ref = "s#{series.id}@2026-10-12"
      assert_difference -> { Planner::Event.where(series_id: series.id).count }, 1 do
        assert_equal true, link([ref, stamps.id.to_s]).first["ok"]
        assert_equal "already", link([ref, stamps.id.to_s]).first["linked"]
      end
      event = Planner::Event.find_by!(series_id: series.id, occurrence_on: "2026-10-12")
      assert linked?(event, stamps)
      call_tool("admin_write", "list_items", {type: "event", from: "2026-10-12", to: "2026-10-12"})
      assert_equal 1, tool_data["items"].first["links"]
    end

    it "takes at most 50 pairs, of exactly two refs" do
      call_tool("admin_write", "link_items", {pairs: Array.new(51) { %w[1 2] }})
      assert_match(/50|maxItems|too many/i, rpc_body.dig("result", "content", 0, "text").to_s + rpc_body.dig("error", "data").to_s)
      call_tool("admin_write", "link_items", {pairs: [[stamps.id.to_s]]})
      assert(rpc_body.dig("result", "isError") || rpc_body["error"])
    end
  end

  describe "unlink_items" do
    let(:tool) { "unlink_items" }
    include McpToolExamples

    def arguments_for(ref) = {pairs: [[ref, stamps.id.to_s]]}

    it "removes a link at once, with no trash" do
      link([stamps.id.to_s, plants.id.to_s])
      result = unlink([plants.id.to_s, stamps.id.to_s]).first
      assert_equal [true, "removed"], [result["ok"], result["unlinked"]]
      refute linked?(stamps, plants)
      assert Planner::Item.exists?(stamps.id)
    end

    it "says when the two were not linked, and leaves other links alone" do
      link([stamps.id.to_s, plants.id.to_s])
      assert_equal "not linked", unlink([stamps.id.to_s, attic.id.to_s]).first["unlinked"]
      assert linked?(stamps, plants)
    end

    it "says an occurrence that is only a date has no links" do
      series = weekly_series
      assert_no_difference -> { Planner::Event.count } do
        assert_equal "not linked", unlink(["s#{series.id}@2026-10-12", stamps.id.to_s]).first["unlinked"]
      end
    end

    it "removes the link to something in the trash too: it is the link that is asked for" do
      dentist = planner_items(:dentist)
      trashed = planner_items(:trashed_task)
      assert linked?(dentist, trashed)
      assert_equal [true, "removed"], unlink([dentist.id.to_s, trashed.id.to_s]).first.values_at("ok", "unlinked")
      refute linked?(dentist, trashed)
    end
  end
end
