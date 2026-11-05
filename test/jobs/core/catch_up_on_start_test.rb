require "test_helper"

describe Core::CatchUpJob, "when the scheduler of the job queue starts" do
  include ActiveJob::TestHelper

  def start_scheduler = SolidQueue::Scheduler.lifecycle_hooks[:start].each { |hook| hook.call(nil) }

  it "enqueues the job in job mode" do
    use_catch_up "job"
    assert_enqueued_with(job: Core::CatchUpJob) { start_scheduler }
  end

  it "enqueues nothing in lazy and off modes" do
    %w[lazy off].each do |word|
      use_catch_up word
      assert_no_enqueued_jobs { start_scheduler }
    end
  end
end
