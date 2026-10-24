# Entities that go to a trash first.
#
# They are purged after RETENTION. There is no default scope: every query says
# what it wants.
module Core::SoftDeletable
  extend ActiveSupport::Concern

  RETENTION = 30.days

  included do
    scope :kept, -> { where(deleted_at: nil) }
    scope :trashed, -> { where.not(deleted_at: nil) }
    scope :purgeable, ->(now = Time.current) { trashed.where(deleted_at: ...(now - RETENTION)) }
  end

  class_methods do
    # Purges what has been in the trash too long.
    #
    # Uses delete_all: no callbacks and no renumbering.
    # The database cascade removes the records and their links.
    def purge_expired(now = Time.current) = purgeable(now).delete_all
  end

  def trashed? = deleted_at.present?

  # Moves the entity to the trash.
  #
  # Skips validations on purpose: a record that became invalid with old data
  # can still be trashed and restored.
  def trash = update_columns(deleted_at: Time.current)

  def restore = update_columns(deleted_at: nil)
end
