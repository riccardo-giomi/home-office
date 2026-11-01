class Planner::Task < Planner::Item
  include Planner::Timed
  include Planner::AlwaysDone

  # The page that lists it, where "Back" goes by default.
  def self.listing_page = :schedule

  # The tasks that are not done, not abandoned, not in the trash and dated
  # before `today`, a date in the time zone of the user. Use with `owned_by`.
  scope :forgotten, ->(today) do
    kept.where(state: "active", done_at: nil).where(day: ...today)
  end
end
