# Removes events of a series, the scope saying which: this one, this and the
# following ones, this and the earlier ones, all.
#
# Nothing is destroyed. Events and series go to the trash, and a date that is
# skipped stays skipped.
#
# - This one: its date is skipped for good (so its unsaved occurrence does not
#   come back, even when its event is purged later), and its event, if it has
#   one, goes to the trash.
# - Following and past cut the series (`ends_on`, `from_on`) and trash the
#   events made from the cut part. They also take the whole parts of the chain
#   beyond the cut. The cut itself stays: a series cannot be un-cut from the
#   trash.
# - A series with nothing left after a cut is trashed instead of being left
#   empty.
# - Everything trashed by one action shares one moment (`deleted_at`), which is
#   how the trash groups it and how a restore finds what went together. What had
#   been trashed earlier keeps its own.
class Planner::Recurrence::Delete
  SCOPES = Planner::Recurrence::ScopeChoice::DELETE

  def initialize(series:, item:, scope:)
    raise ArgumentError, "unknown scope: #{scope}" unless SCOPES.include?(scope)

    @series = series
    @item = item
    @scope = scope
    @day = item.occurrence_on
    @moment = Time.current
  end

  # True when it removed what it should.
  #
  # Otherwise nothing changed, and the reason is in the errors of the item.
  def call
    Planner::Series.transaction { send(:"remove_#{@scope}") }
    true
  rescue ActiveRecord::StaleObjectError
    @item.errors.add(:base, :stale_series)
    false
  end

  private

  def remove_this
    Planner::SeriesExclusion.create_with(user_id: @series.user_id).find_or_create_by!(series_id: @series.id, excluded_on: @day)
    @item.trash if @item.persisted?
  end

  def remove_following
    visible_from = [@series.from_on, @series.starts_on].compact.max
    if @series.dates(visible_from..(@day - 1), skip: []).any?
      @series.update!(ends_on: @day - 1)
    else
      trash_part(@series)
    end
    trash_rows(Planner::Event.where(series_id: @series.id, occurrence_on: @day..))
    parts.select { |part| part.starts_on > @day }.each { |part| trash_part(part) }
  end

  def remove_past
    if next_date
      @series.update!(from_on: @day + 1)
    else
      trash_part(@series)
    end
    trash_rows(Planner::Event.where(series_id: @series.id, occurrence_on: ..@day))
    parts.select { |part| part.starts_on < @series.starts_on }.each { |part| trash_part(part) }
  end

  def remove_all
    parts.each { |part| trash_part(part) }
  end

  # The first date after the occurrence, looking further and further.
  #
  # A rule can give one every few decades.
  def next_date
    [1.year, 10.years, 100.years].each do |span|
      last = [@series.ends_on, @day + span].compact.min
      found = @series.dates((@day + 1)..last, skip: []).first
      return found if found
      break if @series.ends_on && last >= @series.ends_on
    end
    nil
  end

  def parts = @series.chain.reject { |part| part.trashed? || part.id == @series.id }.then { |others| (@scope == "all") ? [@series, *others] : others }

  def trash_part(part)
    Planner::Series.where(id: part.id).update_all(deleted_at: @moment)
    trash_rows(Planner::Event.where(series_id: part.id))
  end

  def trash_rows(rows) = Core::Entity.where(id: rows.select(:id), deleted_at: nil).update_all(deleted_at: @moment)
end
