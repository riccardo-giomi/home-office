require "test_helper"

class McpWritingToolsTest < ActionDispatch::IntegrationTest
  include McpHelpers

  let(:admin) { users(:admin) }

  before { travel_to Time.utc(2026, 10, 7, 12, 0, 0) }

  def run_tool(tool, arguments, as: "admin_write")
    call_tool(as, tool, arguments)
    assert_nil rpc_body["error"], rpc_body["error"].inspect
    tool_data
  end

  def results(tool, arguments) = run_tool(tool, arguments).fetch("results")

  def failure(tool, arguments)
    call_tool("admin_write", tool, arguments)
    assert(rpc_body.dig("result", "isError") || rpc_body["error"], "expected an error for #{arguments.inspect}")
    rpc_body.dig("result", "content", 0, "text") || rpc_body.dig("error", "data").to_s
  end

  def create(arguments) = run_tool("create_item", arguments)

  def update(*changes) = results("update_items", changes:)

  def weekly_series(**attrs)
    Planner::Series.create!({user: admin, title: "Gym", starts_on: Date.new(2026, 10, 12), time_zone: "UTC", rrule: "FREQ=WEEKLY;BYDAY=MO", start_time: "18:00", duration_minutes: 60}.merge(attrs))
  end

  describe "create_item" do
    it "makes an event with times, for the token's user only" do
      data = create(type: "event", title: " Dentist check ", day: "2026-10-20", start: "09:00", end: "09:45", priority: "high", notes: "Bring the card", tracks_done: true)
      assert_equal true, data["ok"]
      event = Planner::Event.find(data["id"])
      assert_equal [admin.id, "Dentist check", Date.new(2026, 10, 20), "09:00", "09:45", "high", "Bring the card", 1], [event.user_id, event.title, event.day, event.start_time, event.end_time, event.priority, event.notes, event.tracks_done]
      assert_equal "event", data["type"]
    end

    it "fills the end 30 minutes after the start, as the form does" do
      data = create(type: "event", title: "Call", day: "2026-10-20", start: "10:00")
      assert_equal "10:30", Planner::Event.find(data["id"]).end_time
    end

    it "makes a task on today when no day is given, and a todo with no day at all" do
      task = Planner::Task.find(create(type: "task", title: "Water the garden")["id"])
      assert_equal Date.new(2026, 10, 7), task.day
      assert_nil task.starts_at
      todo = Planner::Todo.find(create(type: "todo", title: "Learn Ruby", priority: "urgent")["id"])
      assert_equal ["urgent", admin.id], [todo.priority, todo.user_id]
    end

    it "makes a series from an event with repeat fields, and no event" do
      assert_no_difference -> { Planner::Event.count } do
        assert_difference -> { Planner::Series.count }, 1 do
          data = create(type: "event", title: "Gym", day: "2026-10-12", start: "18:00", end: "19:00", repeat: {frequency: "weekly", weekdays: %w[MO WE], ends: "count", count: 5})
          series = Planner::Series.find(data["series"].delete_prefix("s"))
          assert_equal "FREQ=WEEKLY;BYDAY=MO,WE;COUNT=5", series.rrule
          assert_match(/Mon, Wed/, data["repeat"])
          assert_equal ["s#{series.id}@2026-10-12", "s#{series.id}@2026-10-14", "s#{series.id}@2026-10-19"], data["next"]
          assert_nil data["id"]
        end
      end
    end

    it "does not start a repeating event more than a year back, which would make years of past occurrences at once" do
      assert_no_difference -> { Planner::Series.count } do
        assert_match(/more than a year/i, failed_result(type: "event", title: "Old", day: "1900-01-01", repeat: {frequency: "daily"}))
        assert_match(/more than a year/i, failed_result(type: "event", title: "Old", day: "2025-10-06", repeat: {frequency: "daily"}))
      end
      assert_difference -> { Planner::Series.count }, 1 do
        create(type: "event", title: "Not so old", day: "2025-10-07", repeat: {frequency: "weekly"})
      end
    end

    it "gives the next dates even when the rule is sparse" do
      data = create(type: "event", title: "Passport check", day: "2026-10-12", repeat: {frequency: "yearly", interval: 2})
      assert_equal %w[2026-10-12 2028-10-12 2030-10-12], data["next"].map { |name| name.split("@").last }
    end

    it "makes a monthly series on the nth weekday, and one that ends on a date" do
      data = create(type: "event", title: "Book club", day: "2026-10-13", repeat: {frequency: "monthly", monthly: "weekday", ends: "until", until_on: "2027-03-31"})
      assert_equal "FREQ=MONTHLY;BYDAY=2TU;UNTIL=20270331", Planner::Series.find(data["series"].delete_prefix("s")).rrule
    end

    it "says what is wrong with the repeat fields, and makes nothing" do
      assert_no_difference -> { Planner::Series.count } do
        assert_match(/last day|until/i, failed_result(type: "event", title: "X", day: "2026-10-12", repeat: {frequency: "daily", ends: "until"}))
        assert_match(/after|before|start/i, failed_result(type: "event", title: "X", day: "2026-10-12", repeat: {frequency: "daily", ends: "until", until_on: "2026-01-01"}))
      end
    end

    it "does not let a task or a todo repeat" do
      assert_match(/only events repeat/i, failed_result(type: "task", title: "X", repeat: {frequency: "daily"}))
      assert_no_difference -> { Planner::Series.count } do
        call_tool("admin_write", "create_item", {type: "todo", title: "X", repeat: {frequency: "daily"}})
      end
    end

    it "says what is wrong with an item and makes nothing" do
      assert_no_difference -> { Planner::Item.count } do
        assert_match(/title/i, failed_result(type: "task", title: "  "))
        assert_match(/end/i, failed_result(type: "event", title: "X", day: "2026-10-20", start: "10:00", end: "09:00"))
        assert_match(/start/i, failed_result(type: "event", title: "X", day: "2026-10-20", end: "09:00"))
        assert_match(/day/i, failed_result(type: "event", title: "X", day: "tomorrow"))
        assert_match(/255|maxLength|too long/i, failed_result(type: "task", title: "x" * 256))
        assert_match(/event|task|todo/, failed_result(type: "note", title: "X"))
        assert_match(/todo/i, failed_result(type: "todo", title: "X", day: "2026-10-20"))
      end
    end

    it "is not a tool a read-only token has" do
      refute_includes tool_names("member_read"), "create_item"
    end
  end

  # The text of the answer to a create_item that was refused (a tool error, a protocol error or ok: false)
  def failed_result(arguments)
    call_tool("admin_write", "create_item", arguments)
    text = rpc_body["error"] ? rpc_body.dig("error", "data").to_s : rpc_body.dig("result", "content", 0, "text").to_s
    refused = rpc_body["error"] || rpc_body.dig("result", "isError")
    assert refused, "no error for #{arguments.inspect}: #{text}"
    text
  end

  describe "update_items" do
    let(:tool) { "update_items" }
    include McpToolExamples

    def arguments_for(ref) = {changes: [{ref:, title: "Changed"}]}

    it "changes the fields it is given and nothing else" do
      task = planner_items(:pay_rent_task)
      result = update({ref: task.id.to_s, title: "Pay rent now", priority: "urgent", notes: "Online"}).first
      assert_equal [true, task.id.to_s, "Pay rent now", "urgent"], [result["ok"], result["id"], result["title"], result["priority"]]
      task.reload
      assert_equal ["Pay rent now", "urgent", "Online", Date.new(2026, 10, 7), "10:00"], [task.title, task.priority, task.notes, task.day, task.start_time]
    end

    it "moves the day and the times of an item" do
      task = planner_items(:buy_stamps_task)
      update({ref: task.id.to_s, day: "2026-10-15", start: "11:00", end: "11:30"})
      task.reload
      assert_equal [Date.new(2026, 10, 15), "11:00", "11:30"], [task.day, task.start_time, task.end_time]
    end

    it "does several in one call: the good ones are done, the bad one says why" do
      good = planner_items(:buy_stamps_task)
      other = planner_items(:other_users_task)
      results = update({ref: good.id.to_s, title: "Buy more stamps"}, {ref: "999999", title: "x"}, {ref: other.id.to_s, title: "Mine now"}, {ref: planner_items(:holiday).id.to_s, priority: "low"})
      assert_equal [true, false, false, true], results.map { |result| result["ok"] }
      assert_equal "Buy more stamps", good.reload.title
      assert_equal "Someone else's chore", other.reload.title
      assert_equal "low", planner_items(:holiday).reload.priority
      assert_equal "999999", results[1]["ref"]
      assert_match(/not found/i, results[1]["error"])
    end

    it "saves an unsaved occurrence once, however often it is changed, and the same name keeps working" do
      series = weekly_series
      ref = "s#{series.id}@2026-10-12"
      assert_difference -> { Planner::Event.where(series_id: series.id).count }, 1 do
        first = update({ref:, title: "Gym (late)", start: "19:00", end: "20:00"}).first
        assert_equal true, first["ok"]
        assert_equal Planner::Event.find_by!(series_id: series.id, occurrence_on: "2026-10-12").id.to_s, first["id"]
        second = update({ref:, notes: "Leg day"}).first
        assert_equal first["id"], second["id"]
      end
      event = Planner::Event.find_by!(series_id: series.id, occurrence_on: "2026-10-12")
      assert_equal ["Gym (late)", "19:00", "Leg day"], [event.title, event.start_time, event.notes]
      assert_equal "Gym", series.reload.title
    end

    it "does not find a date the rule does not give, or one that was removed" do
      series = weekly_series
      series.exclusions.create!(user_id: admin.id, excluded_on: Date.new(2026, 10, 12))
      assert_match(/not found/i, update({ref: "s#{series.id}@2026-10-12", title: "x"}).first["error"])
      assert_match(/not found/i, update({ref: "s#{series.id}@2026-10-13", title: "x"}).first["error"])
    end

    it "ticks tasks and todos done, and back" do
      task = planner_items(:buy_stamps_task)
      assert_equal true, update({ref: task.id.to_s, done: true}).first["done"]
      assert task.reload.done?
      assert_nil update({ref: task.id.to_s, done: false}).first["done"]
      refute task.reload.done?
      todo = planner_items(:water_plants_todo)
      update({ref: todo.id.to_s, done: true})
      assert todo.reload.done?
    end

    it "ticks an event only when it has a done box" do
      rent = planner_items(:rent_open)
      assert_equal true, update({ref: rent.id.to_s, done: true}).first["ok"]
      assert rent.reload.done?
      holiday = planner_items(:holiday)
      result = update({ref: holiday.id.to_s, done: true}).first
      assert_equal false, result["ok"]
      assert_match(/done box|does not track/i, result["error"])
      refute holiday.reload.done?
    end

    it "changes the state in the ways the pages allow, and says which are allowed when not" do
      task = planner_items(:buy_stamps_task)
      assert_equal "abandoned", update({ref: task.id.to_s, state: "abandoned"}).first["state"]
      assert_equal "abandoned", task.reload.state
      assert_nil update({ref: task.id.to_s, state: "active"}).first["state"]
      refused = update({ref: task.id.to_s, state: "cancelled"}).first
      assert_equal false, refused["ok"]
      assert_match(/abandoned/, refused["error"])
      assert_equal "active", task.reload.state
      event = planner_items(:holiday)
      assert_equal "cancelled", update({ref: event.id.to_s, state: "cancelled"}).first["state"]
    end

    it "does not take done and a new state in one change, which could leave an item both cancelled and done" do
      rent = planner_items(:rent_open)
      result = update({ref: rent.id.to_s, done: true, state: "cancelled"}).first
      assert_equal false, result["ok"]
      assert_match(/separate/i, result["error"])
      rent.reload
      assert_equal ["active", false], [rent.state, rent.done?]
    end

    it "says what a kind cannot take" do
      todo = planner_items(:call_mom_todo)
      result = update({ref: todo.id.to_s, day: "2026-10-20"}).first
      assert_equal false, result["ok"]
      assert_match(/day/, result["error"])
      assert_match(/title|notes|priority/, result["error"])
      task = planner_items(:buy_stamps_task)
      assert_match(/tracks_done/, update({ref: task.id.to_s, tracks_done: true}).first["error"])
    end

    it "says what the item's own rules refuse, with the reasons, and changes nothing" do
      task = planner_items(:pay_rent_task)
      result = update({ref: task.id.to_s, title: " ", start: "10:00", end: "09:00"}).first
      assert_equal false, result["ok"]
      assert_match(/title/i, result["error"])
      assert_equal "Pay the rent", task.reload.title
    end

    it "changes all occurrences of a series: the template, the untouched ones follow, and an occurrence changed on its own keeps its other fields" do
      series = weekly_series(notes: "Bring a towel")
      edited = series.materialize(Date.new(2026, 10, 12))
      edited.update!(notes: "Leg day")
      result = update({ref: "s#{series.id}@2026-10-19", scope: "all", title: "Gym class", start: "17:00", end: "18:00", priority: "high"}).first
      assert_equal true, result["ok"]
      series.reload
      assert_equal ["Gym class", "17:00", 60, "high", "Bring a towel"], [series.title, series.start_time, series.duration_minutes, series.priority, series.notes]
      edited.reload
      assert_equal ["Gym class", "Leg day", "17:00"], [edited.title, edited.notes, edited.start_time]
      listed = run_tool("list_items", {type: "event", from: "2026-10-26", to: "2026-10-26"})
      assert_equal ["Gym class", "17:00"], listed["items"].first.values_at("title", "start")
    end

    it "refuses what scope all cannot do: the day, done, the state, a plain item" do
      series = weekly_series
      ref = "s#{series.id}@2026-10-19"
      assert_match(/day/i, update({ref:, scope: "all", day: "2026-10-20"}).first["error"])
      assert_match(/one occurrence|scope.*this/i, update({ref:, scope: "all", done: true}).first["error"])
      assert_match(/one occurrence|scope.*this/i, update({ref:, scope: "all", state: "cancelled"}).first["error"])
      assert_match(/occurrence/i, update({ref: planner_items(:holiday).id.to_s, scope: "all", title: "x"}).first["error"])
      assert_equal "Gym", series.reload.title
    end

    it "takes at most 50 changes in a call, and no repeat rule" do
      assert_match(/50|maxItems|too many/i, failure("update_items", {changes: Array.new(51) { {ref: "1", title: "x"} }}))
      assert_match(/repeat|additional/i, failure("update_items", {changes: [{ref: planner_items(:holiday).id.to_s, repeat: {frequency: "daily"}}]}))
    end

    it "is not a tool a read-only token has" do
      refute_includes tool_names("member_read"), "update_items"
    end
  end

  describe "trash_items" do
    let(:tool) { "trash_items" }
    include McpToolExamples

    def arguments_for(ref) = {refs: [ref]}

    it "moves items to the trash, where the trash lists them and they are not listed any more" do
      task = planner_items(:buy_stamps_task)
      results = results("trash_items", refs: [task.id.to_s, planner_items(:call_mom_todo).id.to_s])
      assert_equal [true, true], results.map { |result| result["ok"] }
      assert task.reload.trashed?
      titles = run_tool("list_items", {trashed: true})["items"].map { |item| item["title"] }
      assert_includes titles, "Buy stamps"
      refute_includes run_tool("list_items", {type: "task"})["items"].map { |item| item["title"] }, "Buy stamps"
    end

    it "removes one occurrence: its date is skipped and no event is made" do
      series = weekly_series
      assert_no_difference -> { Planner::Event.count } do
        assert_equal true, results("trash_items", refs: ["s#{series.id}@2026-10-12"]).first["ok"]
      end
      assert_equal [Date.new(2026, 10, 12)], Planner::SeriesExclusion.where(series_id: series.id).pluck(:excluded_on)
      dates = run_tool("list_items", {type: "event", from: "2026-10-12", to: "2026-10-26"})["items"].map { |item| item["id"] }
      assert_equal ["s#{series.id}@2026-10-19", "s#{series.id}@2026-10-26"], dates
    end

    it "trashes the row of a saved occurrence and skips its date" do
      series = weekly_series
      row = series.materialize(Date.new(2026, 10, 12))
      results("trash_items", refs: [row.id.to_s])
      assert Planner::Item.includes(:entity).find(row.id).trashed?
    end

    it "trashes a whole series with scope all, from any of its occurrences" do
      series = weekly_series
      assert_equal true, results("trash_items", refs: ["s#{series.id}@2026-10-19"], scope: "all").first["ok"]
      assert series.reload.trashed?
      assert_equal "s#{series.id}", run_tool("list_items", {trashed: true})["items"].first["id"]
    end

    it "says a thing already in the trash was not found" do
      assert_match(/not found/i, results("trash_items", refs: [planner_items(:trashed_event).id.to_s]).first["error"])
    end

    it "takes at most 50 refs" do
      assert_match(/50|maxItems|too many/i, failure("trash_items", {refs: Array.new(51) { "1" }}))
    end
  end

  describe "restore_items" do
    let(:tool) { "restore_items" }
    include McpToolExamples

    def arguments_for(ref) = {refs: [ref]}

    it "takes an item out of the trash, as it was" do
      event = planner_items(:trashed_event)
      assert_equal true, results("restore_items", refs: [event.id.to_s]).first["ok"]
      refute event.reload.trashed?
      assert_includes run_tool("list_items", {from: "2026-10-07", to: "2026-10-07"})["items"].map { |item| item["title"] }, "Thrown away event"
    end

    it "takes a series out of the trash with what went with it, named s<id>" do
      series = weekly_series
      results("trash_items", refs: ["s#{series.id}@2026-10-19"], scope: "all")
      assert_equal true, results("restore_items", refs: ["s#{series.id}"]).first["ok"]
      refute series.reload.trashed?
    end

    it "says something that is not in the trash was not found there" do
      result = results("restore_items", refs: [planner_items(:holiday).id.to_s]).first
      assert_equal false, result["ok"]
      assert_match(/not found in the trash/i, result["error"])
    end

    it "does not take another user's series out of the trash" do
      other = Planner::Series.create!(user: users(:other_admin), title: "Theirs", starts_on: Date.new(2026, 10, 5), time_zone: "UTC", rrule: "FREQ=DAILY", deleted_at: 1.day.ago)
      assert_match(/not found/i, results("restore_items", refs: ["s#{other.id}"]).first["error"])
      assert other.reload.trashed?
    end

    it "is not a tool a read-only token has" do
      refute_includes tool_names("member_read"), "restore_items"
    end
  end
end
