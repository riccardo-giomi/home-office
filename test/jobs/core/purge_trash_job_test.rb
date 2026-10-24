require "test_helper"

describe Core::PurgeTrashJob do
  it "deletes what has been in the trash past its time, its record with it, and nothing else" do
    expired_id = planner_items(:expired_event).id
    kept = Planner::Item.kept.count
    recent = Planner::Item.trashed.count - 1
    items = Planner::Item.count
    Core::PurgeTrashJob.perform_now
    assert_nil Planner::Item.find_by(id: expired_id)
    assert_nil Core::Entity.find_by(id: expired_id)
    _(Planner::Item.count).must_equal items - 1
    _(Planner::Item.kept.count).must_equal kept
    _(Planner::Item.trashed.count).must_equal recent
  end

  it "does nothing the second time" do
    Core::PurgeTrashJob.perform_now
    assert_no_difference ["Planner::Item.count", "Core::Entity.count"] do
      Core::PurgeTrashJob.perform_now
    end
  end

  it "waits for the 30 days to be over, to the second" do
    item = planner_items(:holiday)
    item.entity.update_columns(deleted_at: 30.days.ago + 1.minute)
    Core::PurgeTrashJob.perform_now
    _(Planner::Item.exists?(item.id)).must_equal true
    travel 2.minutes
    Core::PurgeTrashJob.perform_now
    _(Planner::Item.exists?(item.id)).must_equal false
  end

  it "runs from the background queue the workers serve" do
    _(Core::PurgeTrashJob.new.queue_name).must_equal "background"
    workers = YAML.load(ERB.new(Rails.root.join("config/queue.yml").read).result, aliases: true).dig("production", "workers")
    _(workers.flat_map { |worker| Array(worker["queues"]) }).must_include "*"
  end
end
