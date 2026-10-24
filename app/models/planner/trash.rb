# What a person has in the trash.
#
# The counts for each kind, the list (all kinds or one), and emptying it.
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
      KINDS.index_with { |kind| by_type.fetch(sti_name(kind), 0) }
    end
  end

  # How many items are in the trash, all kinds.
  #
  # Its own query on purpose: it is the sidebar's number, asked on every page,
  # so it is a plain count (joined with the entity) with no grouping. The
  # grouped count above is only for the trash pages.
  def total = @total ||= scope.count

  # The trashed items, newest first.
  #
  # The entity comes along, so the day it was trashed needs no query for each
  # row.
  def items
    items = scope.eager_load(:entity)
      .order("core_entities.deleted_at DESC, planner_items.id DESC")
    @type ? items.where(type: sti_name(@type)) : items
  end

  # Empties the trash, whichever kind is being looked at.
  #
  # Returns how many were deleted.
  def empty! = Core::Entity.where(id: scope.select(:id)).delete_all

  private

  def scope = Planner::Item.owned_by(@user).trashed

  def sti_name(kind) = Planner::Item.sti_class_for("Planner::#{kind.camelize}").sti_name
end
