require "test_helper"

class McpReadingToolsTest < ActionDispatch::IntegrationTest
  include McpHelpers

  let(:admin) { users(:admin) }
  let(:now) { Time.utc(2026, 10, 7, 12, 0, 0) }

  before { travel_to(now) }

  def listed(**arguments)
    call_tool("admin_write", "list_items", arguments)
    assert_nil rpc_body["error"], rpc_body.inspect
    refute rpc_body.dig("result", "isError"), rpc_body.dig("result", "content", 0, "text")
    tool_data
  end

  def titles(**arguments) = listed(**arguments).fetch("items").map { |item| item["title"] }

  def failure(tool, arguments)
    call_tool("admin_write", tool, arguments)
    assert rpc_body.dig("result", "isError") || rpc_body["error"], "expected an error for #{arguments.inspect}"
    rpc_body.dig("result", "content", 0, "text") || [rpc_body.dig("error", "message"), rpc_body.dig("error", "data")].join(" ")
  end

  # The query cache would answer a repeated request from memory and hide the questions asked
  def uncached_selects(&block) = ActiveRecord::Base.uncached { selects(&block) }

  def weekly_series(**attrs)
    Planner::Series.create!({user: admin, title: "Gym", starts_on: Date.new(2026, 10, 5), time_zone: "Europe/Rome", rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "18:00", duration_minutes: 60}.merge(attrs))
  end

  describe "list_items" do
    it "gives the next two weeks of what is active, events and tasks together by day, then the todos in their order" do
      found = titles
      assert_equal ["Dentist", "Pay the rent"], found.first(2)
      assert_equal ["Bank holiday", "Buy stamps"], found[2, 2].sort
      assert_equal ["Water the plants", "Call mom", "Finish the book", "Renew the license"], found.drop(4)
    end

    it "says the zone once and how many there are" do
      data = listed
      assert_equal "UTC", data["time_zone"]
      assert_equal 8, data["total"]
      assert_nil data["more"]
    end

    it "describes an item compactly: no nulls, no defaults, local clock times and the item's own zone when it differs" do
      dentist = listed(q: "Dentist").fetch("items").first
      assert_equal({"id" => planner_items(:dentist).id.to_s, "type" => "event", "title" => "Dentist", "day" => "2026-10-07", "start" => "09:30", "end" => "10:00", "time_zone" => "Europe/Rome", "links" => 2}, dentist)
      assert_equal({"id" => planner_items(:holiday).id.to_s, "type" => "event", "title" => "Bank holiday", "day" => "2026-10-08"}, listed(q: "holiday").fetch("items").first)
      call_tool("admin_write", "list_items", {type: "todo", q: "mom"})
      assert_equal({"id" => planner_items(:call_mom_todo).id.to_s, "type" => "todo", "title" => "Call mom", "priority" => "high"}, tool_data.fetch("items").first)
    end

    it "marks what is done, and what tracks it" do
      assert_equal ["Call the bank"], titles(type: "task", done: true, from: "2026-10-01", to: "2026-10-31")
      item = listed(q: "Rent October", from: "2026-10-01", to: "2026-10-31").fetch("items").first
      assert_equal [true, true], [item["done"], item["tracks_done"]]
    end

    it "filters by type, day range, state and done" do
      assert_equal ["Pay the rent", "Buy stamps"], titles(type: "task")
      assert_equal ["Dentist"], titles(type: "event", from: "2026-10-07", to: "2026-10-07")
      assert_equal ["Sort the attic"], titles(state: "abandoned", from: "2026-10-01", to: "2026-10-31")
      assert_equal ["Cancelled workshop"], titles(state: "cancelled", from: "2026-10-01", to: "2026-10-31")
      assert_includes titles(state: "any", from: "2026-10-01", to: "2026-10-31"), "Sort the attic"
      assert_equal ["Water the plants", "Call mom", "Renew the license"], titles(type: "todo", done: false)
      assert_equal ["Finish the book"], titles(type: "todo", done: true)
    end

    it "finds by a part of the title, taking % and _ literally" do
      assert_equal ["Pay the rent"], titles(q: "THE RENT")
      assert_empty titles(q: "%")
      Planner::Todo.create!(user: admin, title: "100% done")
      assert_equal ["100% done"], titles(q: "%")
    end

    it "pages with a limit and an offset, and says there is more" do
      page = listed(limit: 3)
      assert_equal 3, page["items"].size
      assert_equal [8, true], [page["total"], page["more"]]
      assert_equal ["Call mom", "Finish the book", "Renew the license"], listed(limit: 3, offset: 5).fetch("items").map { |item| item["title"] }
      assert_nil listed(limit: 3, offset: 5)["more"]
    end

    it "shows the occurrences of a series as unsaved occurrences named by series and date, and the same name after one is saved" do
      series = weekly_series
      unsaved = listed(type: "event", from: "2026-10-12", to: "2026-10-12").fetch("items").first
      assert_equal "s#{series.id}@2026-10-12", unsaved["id"]
      assert_equal %w[Gym 18:00 19:00], unsaved.values_at("title", "start", "end")
      series.materialize(Date.new(2026, 10, 12))
      saved = listed(type: "event", from: "2026-10-12", to: "2026-10-12").fetch("items").first
      assert_equal Planner::Event.find_by!(series_id: series.id, occurrence_on: "2026-10-12").id.to_s, saved["id"]
      assert_equal "s#{series.id}@2026-10-12", saved["occurrence"]
    end

    it "gives the three views the pages have, with the numbers the badges show" do
      Planner::Event.create!(user: admin, title: "Pay tax", day: Date.new(2026, 10, 1), tracks_done: 1)
      Planner::Event.create!(user: admin, title: "Board meeting", day: Date.new(2026, 10, 9), priority: "urgent")
      assert_equal ["Renew the passport"], titles(view: "forgotten")
      assert_equal ["Pay tax"], titles(view: "missed")
      assert_equal ["Board meeting"], titles(view: "important")
      counts = Planner::Counts.for(admin)
      assert_equal [counts.forgotten, counts.missed, counts.important], [1, 1, 1]
    end

    it "refuses to mix a view with filters it would ignore, and says so" do
      {type: "task", from: "2026-10-07", to: "2026-10-09", state: "any", done: true}.each do |name, value|
        message = failure("list_items", {:view => "missed", name => value})
        assert_match(/view/i, message, name)
        assert_match(/#{name}/, message)
      end
      assert_equal ["Renew the passport"], titles(view: "forgotten", q: "passport", limit: 5, offset: 0)
    end

    it "lists the trash, with what is trashed first, and a trashed series as one entry" do
      series = weekly_series(title: "Old class")
      series.update_columns(deleted_at: 1.hour.ago)
      data = listed(trashed: true)
      assert_equal "Old class", data["items"].first["title"]
      assert_equal "s#{series.id}", data["items"].first["id"]
      assert_includes data["items"].map { |item| item["title"] }, "Thrown away event"
      assert data["items"].all? { |item| item["trashed"] }
      assert_equal ["Thrown away event"], listed(trashed: true, type: "event", q: "thrown").fetch("items").map { |item| item["title"] }
    end

    it "never gives another user's items, not even to a search for them" do
      assert_empty titles(q: "Someone else's", state: "any", from: "2026-10-01", to: "2026-10-31")
      assert_empty titles(q: "Someone else's", trashed: true)
      refute_includes titles(type: "todo"), "Someone else's todo"
    end

    it "uses the user's today, not UTC's" do
      admin.update!(time_zone: "Pacific/Auckland")
      travel_to(Time.utc(2026, 10, 7, 23, 30))
      assert_equal "2026-10-08", listed(type: "task").fetch("items").map { |item| item["day"] }.min
      travel_to(Time.utc(2026, 10, 7, 10, 0))
      assert_equal "2026-10-07", listed(type: "task").fetch("items").map { |item| item["day"] }.min
    end

    it "explains what was wrong with the input" do
      assert_match(/ISO 8601 date/, failure("list_items", {from: "next week"}))
      assert_match(/ISO 8601 date/, failure("list_items", {to: "2026-02-30"}))
      assert_match(/before/, failure("list_items", {from: "2026-10-10", to: "2026-10-01"}))
      assert_match(/366 days/, failure("list_items", {from: "2026-01-01", to: "2027-12-31"}))
      assert_match(/\/type.*not one of: \["event", "task", "todo"\]/, failure("list_items", {type: "note"}))
      assert_match(/\/limit.*greater than: 200/, failure("list_items", {limit: 500}))
      assert_match(/\/state.*not one of: \["active", "abandoned", "cancelled", "any"\]/, failure("list_items", {state: "gone"}))
    end

    it "asks no more questions with sixty items than with three" do
      small = uncached_selects { call_tool("admin_write", "list_items", {type: "task", from: "2026-10-01", to: "2026-10-31"}) }.size
      60.times { |i| Planner::Task.create!(user: admin, title: "Bulk #{i}", day: Date.new(2026, 10, 1) + (i % 28)) }
      big = uncached_selects { call_tool("admin_write", "list_items", {type: "task", from: "2026-10-01", to: "2026-10-31", limit: 100}) }.size
      assert_equal small, big
      assert_operator tool_data["items"].size, :>, 60
    end

    it "is a tool a read-only token has" do
      assert_includes tool_names("member_read"), "list_items"
    end
  end

  describe "get_item" do
    it "gives the whole item: notes in full, and its links" do
      planner_items(:dentist).update!(notes: "x" * 500)
      call_tool("admin_write", "get_item", {ref: planner_items(:dentist).id.to_s})
      item = tool_data
      assert_equal 500, item["notes"].size
      assert_equal "Dentist", item["title"]
      links = item["links"]
      assert_equal 3, links.size
      assert_equal "Pay the rent", links.find { |link| link["type"] == "task" && !link["trashed"] }["title"]
      assert_equal 1, links.count { |link| link["trashed"] }
    end

    it "cuts long notes in a list and says so" do
      planner_items(:dentist).update!(notes: "y" * 500)
      item = listed(q: "Dentist").fetch("items").first
      assert_equal 200, item["notes"].size
      assert_equal true, item["notes_truncated"]
    end

    it "gives an unsaved occurrence and the series it belongs to, in words" do
      series = weekly_series(rrule: "FREQ=WEEKLY;INTERVAL=2;BYDAY=MO")
      call_tool("admin_write", "get_item", {ref: "s#{series.id}@2026-10-19"})
      item = tool_data
      assert_equal "s#{series.id}@2026-10-19", item["id"]
      assert_equal({"id" => "s#{series.id}", "repeat" => "Every 2 weeks on Mon"}, item["series"])
    end

    it "does not find what is not theirs, what is in the trash, or what is not a ref, and says how to name one" do
      [planner_items(:other_users_event).id.to_s, planner_items(:trashed_event).id.to_s, "999999999", "s1@2026-10-12", "abc", ""].each do |ref|
        message = failure("get_item", {ref:})
        assert_match(/not found|Not found/i, message, ref)
        assert_match(/s<series id>@YYYY-MM-DD|s7@2026-11-03/, message)
      end
    end
  end

  describe "overview" do
    it "reports the status of the plans in one answer: today, the cards, and the lists that need a look" do
      Planner::Event.create!(user: admin, title: "Board meeting", day: Date.new(2026, 10, 9), priority: "urgent")
      call_tool("admin_write", "overview")
      data = tool_data
      assert_equal "2026-10-07", data["today"]
      cards = data["cards"].to_h { |card| [card["title"], card] }
      assert_equal %w[Events Tasks Todos Trash], cards.keys
      assert_equal({"label" => "Important", "count" => 1}, cards["Events"]["lines"].find { |line| line["label"] == "Important" })
      planner = data.fetch("planner")
      assert_equal ["Dentist"], planner["today"]["items"].select { |item| item["type"] == "event" }.map { |item| item["title"] }
      assert_equal ["Board meeting"], planner["important"]["items"].map { |item| item["title"] }
      assert_equal ["Renew the passport"], planner["forgotten"]["items"].map { |item| item["title"] }
      refute_includes planner.keys, "missed"
    end

    it "caps each list at ten and gives the total" do
      12.times { |i| Planner::Task.create!(user: admin, title: "Late #{i}", day: Date.new(2026, 9, 1) + i) }
      call_tool("admin_write", "overview")
      forgotten = tool_data.dig("planner", "forgotten")
      assert_equal 10, forgotten["items"].size
      assert_equal 13, forgotten["total"]
    end

    it "counts only the signed-in user's things" do
      call_tool("member_write", "overview")
      lines = tool_data["cards"].flat_map { |card| card["lines"] }
      assert lines.all? { |line| line["count"].zero? }, lines.inspect
      assert_nil tool_data["planner"]
    end

    it "asks no more questions with sixty items than with three" do
      small = uncached_selects { call_tool("admin_write", "overview") }.size
      60.times { |i| Planner::Task.create!(user: admin, title: "Bulk #{i}", day: Date.new(2026, 10, 7)) }
      big = uncached_selects { call_tool("admin_write", "overview") }.size
      assert_equal small, big
    end

    it "is a tool a read-only token has" do
      assert_includes tool_names("member_read"), "overview"
      assert_includes tool_names("member_read"), "get_item"
    end
  end
end
