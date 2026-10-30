# What a person has in the trash.
#
# The counts for each kind, the list (all kinds or one), and emptying it.
#
# A series that was trashed is one entry of the events, whatever it holds. The
# events that went to the trash with it are not listed on their own.
class Planner::Trash
  KINDS = %w[event task todo].freeze

  # The kind a request asked for, or nil for all.
  #
  # An unknown word is not an error, just everything.
  def self.kind(value) = value.to_s.presence_in(KINDS)

  attr_reader :type

  def initialize(user, type: nil)
    @user = user
    @type = self.class.kind(type)
  end

  # How many are in the trash for each kind, zeros included.
  #
  # For example {"event" => 2, "task" => 0, "todo" => 1}.
  def counts
    @counts ||= begin
      by_type = scope.group(:type).count
      counts = KINDS.index_with { |kind| by_type.fetch(sti_name(kind), 0) }
      counts.merge("event" => counts.fetch("event") + all_series_groups.size)
    end
  end

  # How many items are in the trash, all kinds.
  #
  # Its own query on purpose: it is the sidebar's number, asked on every page,
  # so it is a plain count (joined with the entity) with no grouping. The
  # grouped count above is only for the trash pages.
  def total = @total ||= scope.count + all_series_groups.size

  # The trashed items, newest first.
  #
  # The entity comes along, so the day it was trashed needs no query for each
  # row.
  def items
    items = scope.eager_load(:entity)
      .order("core_entities.deleted_at DESC, planner_items.id DESC")
    @type ? items.where(type: sti_name(@type)) : items
  end

  # The trashed series, newest first, for the kinds that hold events.
  def series_groups = (@type.nil? || @type == "event") ? all_series_groups : []

  # Empties the trash, whichever kind is being looked at.
  #
  # Returns how many were deleted.
  def empty!
    groups = all_series_groups.size
    Planner::Series.transaction do
      Planner::Series.purge(Planner::Series.owned_by(@user).trashed)
      Core::Entity.where(id: scope.select(:id)).delete_all + groups
    end
  end

  private

  # The trashed items of the user, but not the events that went with a series
  # (trashed at its moment): the series stands for them. An event trashed on its
  # own before that is listed, and can be restored on its own.
  def scope
    Planner::Item.owned_by(@user).trashed.where(<<~SQL.squish)
      planner_items.series_id IS NULL OR NOT EXISTS (
        SELECT 1 FROM planner_series
        WHERE planner_series.id = planner_items.series_id
        AND planner_series.deleted_at = core_entities.deleted_at)
    SQL
  end

  def all_series_groups = @all_series_groups ||= Planner::Series.trash_groups(@user)

  def sti_name(kind) = Planner::Item.sti_class_for("Planner::#{kind.camelize}").sti_name
end
