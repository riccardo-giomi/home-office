require "test_helper"

class CatchUpTest < ActionDispatch::IntegrationTest
  let(:member) { users(:member) }
  let(:other) { users(:other_admin) }

  before do
    member.update!(time_zone: "Europe/Rome", locale: "en")
    use_catch_up "lazy"
    # 01:30 on the 12th in Rome, still the 11th in UTC
    travel_to Time.utc(2026, 10, 11, 23, 30)
  end

  def gym(user, **attrs)
    Planner::Series.create!({user:, title: "Gym", starts_on: Date.new(2026, 10, 9), time_zone: "Europe/Rome",
                             rrule: "FREQ=DAILY", tracks_done: 1}.merge(attrs))
  end

  def made(series) = Planner::Event.where(series_id: series.id).order(:day).pluck(:day).map(&:to_s)

  def item_inserts(&block)
    inserts = []
    callback = ->(*, payload) { inserts << payload[:sql] if payload[:sql].start_with?('INSERT INTO "planner_items"') }
    ActiveSupport::Notifications.subscribed(callback, "sql.active_record", &block)
    inserts
  end

  it "makes the occurrences up to yesterday, in the user's zone, on a signed-in request" do
    mine = gym(member)
    sign_in_as member
    get root_path
    _(made(mine)).must_equal %w[2026-10-09 2026-10-10 2026-10-11]
  end

  it "asks nothing to be inserted the second time" do
    mine = gym(member)
    sign_in_as member
    get root_path
    _(made(mine).size).must_equal 3
    _(item_inserts { get root_path }).must_be :empty?
  end

  it "does nothing when it is off" do
    mine = gym(member)
    sign_in_as member
    use_catch_up "off"
    get root_path
    _(made(mine)).must_be :empty?
  end

  it "does nothing for a visitor who is not signed in" do
    mine = gym(member)
    get new_session_path
    _(made(mine)).must_be :empty?
  end

  it "makes only the signed-in user's occurrences" do
    mine = gym(member)
    theirs = gym(other)
    sign_in_as member
    get root_path
    _(made(mine).size).must_equal 3
    _(made(theirs)).must_be :empty?
  end

  it "makes nothing for a series that does not track done" do
    plain = gym(member, tracks_done: 0)
    sign_in_as member
    get root_path
    _(made(plain)).must_be :empty?
  end

  it "still shows the page when a module's catch-up fails" do
    saved = Core::Modules.all
    Core::Modules.register(Core::ModuleManifest.new(name: "broken", catch_up: ->(_user, _today) { raise "boom" }))
    sign_in_as member
    get root_path
    assert_response :success
  ensure
    Core::Modules.reset!
    saved.each { |manifest| Core::Modules.register(manifest) }
  end
end
