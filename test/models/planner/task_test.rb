require "test_helper"

describe Planner::Task do
  let(:user) { users(:admin) }

  def build(**attrs) = Planner::Task.new({user:, title: "Pay the rent", day: Date.new(2026, 10, 7)}.merge(attrs))

  it "needs a title and a day" do
    _(build.save).must_equal true
    _(build(title: " ").tap(&:valid?).errors[:title]).wont_be_empty
    _(build(day: nil).tap(&:valid?).errors[:day]).wont_be_empty
  end

  it "always tracks done, whatever is assigned" do
    _(build.tracks_done?).must_equal true
    task = build(tracks_done: 0)
    task.save!
    _(task.reload.tracks_done).must_equal 1
  end

  it "takes times like an event: 30-minute default end, same day, clear errors" do
    task = build(start_time: "09:30")
    task.save!
    _(task.end_time).must_equal "10:00"
    _(build(start_time: "09:30", end_time: "09:00").tap(&:valid?).errors[:end_time]).wont_be_empty
    _(build(start_time: "nine").tap(&:valid?).errors[:start_time]).wont_be_empty
    _(build(end_time: "10:00").tap(&:valid?).errors[:start_time]).wont_be_empty
  end

  it "is done when ticked and not done when unticked" do
    task = build.tap(&:save!)
    task.mark_done(true)
    _(task.done?).must_equal true
    task.mark_done(false)
    _(task.done?).must_equal false
  end
end
