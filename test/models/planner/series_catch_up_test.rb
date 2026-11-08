require "test_helper"

describe "Planner::Series catch-up" do
  let(:user) { users(:member) }
  let(:today) { Date.new(2026, 10, 11) }
  let(:yesterday) { today - 1 }

  before { travel_to Time.utc(2026, 10, 11, 12) }

  def series(**attrs)
    Planner::Series.create!({user:, title: "Gym", starts_on: today - 5, time_zone: "Europe/Rome", rrule: "FREQ=DAILY",
                             start_time: "18:00", duration_minutes: 60, tracks_done: 1, priority: "high"}.merge(attrs))
  end

  def events(series) = Planner::Event.where(series_id: series.id).order(:occurrence_on)

  describe "#catch_up" do
    it "makes an event of every occurrence up to the day, from the template" do
      gym = series
      _(gym.catch_up(yesterday)).must_equal 5
      first = events(gym).first
      _(events(gym).map { |event| event.occurrence_on.to_s }).must_equal((today - 5..yesterday).map(&:to_s))
      _(first.attributes.slice("title", "day", "tracks_done", "time_zone", "priority", "state")).must_equal(
        {"title" => "Gym", "day" => today - 5, "tracks_done" => 1, "time_zone" => "Europe/Rome", "priority" => "high", "state" => "active"}
      )
      _(first.start_time).must_equal "18:00"
      _(first.end_time).must_equal "19:00"
      _(Planner::Event.includes(:entity).find(first.id).entity.user_id).must_equal user.id
    end

    it "gives the new events positions after the user's others, each its own" do
      last = Planner::Event.where(user:).maximum(:position)
      series.catch_up(yesterday)
      positions = Planner::Event.where.not(series_id: nil).where(user:).pluck(:position)
      _(positions.uniq.size).must_equal 5
      _(positions.min).must_be :>, last.to_i
    end

    it "moves the watermark without touching the lock version" do
      gym = series
      gym.catch_up(yesterday)
      _(gym.reload.materialized_through).must_equal yesterday
      _(gym.lock_version).must_equal 0
    end

    it "makes nothing the second time" do
      gym = series
      gym.catch_up(yesterday)
      _(gym.catch_up(yesterday)).must_equal 0
      _(events(gym).count).must_equal 5
    end

    it "resumes the day after the watermark" do
      gym = series
      gym.catch_up(today - 3)
      _(gym.catch_up(yesterday)).must_equal 2
    end

    it "does not make a date that has an event, whatever its state, or one that was deleted" do
      gym = series
      gym.build_occurrence(today - 5).tap(&:save!).trash
      gym.build_occurrence(today - 4).tap(&:save!).change_state("abandoned")
      gym.exclusions.create!(user_id: user.id, excluded_on: today - 3)
      _(gym.catch_up(yesterday)).must_equal 2
    end

    it "keeps to the visible span" do
      gym = series(from_on: today - 3, ends_on: today - 2)
      _(gym.catch_up(yesterday)).must_equal 2
    end

    it "survives a rival that made a date first" do
      gym = series
      rival = Planner::Series.find(gym.id)
      gym.define_singleton_method(:dates) do |*args, **options|
        found = super(*args, **options)
        (@raced = true) && rival.build_occurrence(found.first).save! unless @raced
        found
      end
      gym.catch_up(yesterday)
      _(events(gym).count).must_equal 5
    end
  end

  describe ".catch_up" do
    it "catches up the live series of the user that track done" do
      mine = series
      trashed = series(title: "Old")
      Planner::Series.where(id: trashed.id).update_all(deleted_at: Time.current)
      theirs = series(user: users(:other_admin))
      future = series(starts_on: today + 2)
      _(Planner::Series.catch_up(user, today:)).must_equal 5
      _(events(mine).count).must_equal 5
      [trashed, theirs, future].each { |other| _(events(other).count).must_equal 0 }
    end

    it "makes nothing for a series that does not track done: nothing can be missed" do
      plain = series(tracks_done: 0)
      _(Planner::Series.catch_up(user, today:)).must_equal 0
      _(events(plain).count).must_equal 0
      _(plain.reload.materialized_through).must_be_nil
    end
  end

  describe "unsaved occurrences" do
    it "are only for the days after the watermark" do
      gym = series
      gym.catch_up(yesterday)
      shown = Planner::Occurrences.for(user, (today - 5)..(today + 1))
      _(shown.select { |event| event.series_id == gym.id }.map { |event| [event.day, event.persisted?] }).must_equal(
        (today - 5..yesterday).map { |day| [day, true] } + [[today, false], [today + 1, false]]
      )
    end

    it "do not offer a past date that has no event" do
      gym = series
      gym.catch_up(yesterday)
      Planner::Event.where(series_id: gym.id, occurrence_on: today - 2).first.update_columns(series_id: nil, occurrence_on: nil)
      _(gym.occurrence(today - 2)).must_be_nil
      _(gym.occurrence(today)).wont_be_nil
    end

    it "are all there when nothing was made yet" do
      gym = series
      _(Planner::Occurrences.for(user, (today - 5)..yesterday).count { |event| event.series_id == gym.id }).must_equal 5
    end

    it "stay for the past of a series that does not track done" do
      plain = series(tracks_done: 0)
      Planner::Series.catch_up(user, today:)
      shown = Planner::Occurrences.for(user, (today - 5)..yesterday).select { |event| event.series_id == plain.id }
      _(shown.map(&:persisted?).uniq).must_equal [false]
      _(shown.size).must_equal 5
    end
  end
end
