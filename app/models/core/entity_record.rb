# What a module's record class must include to be an entity's record.
#
# The table keeps its own `user_id` (a `belongs_to :user`), guarded by the
# composite key to the entity.
module Core::EntityRecord
  extend ActiveSupport::Concern

  def self.record_classes = (@record_classes ||= Set.new)

  included do
    Core::EntityRecord.record_classes << base_class

    # optional: the foreign key guarantees the entity, and a presence check
    # would load it (strict loading).
    belongs_to :entity, class_name: "Core::Entity", foreign_key: :id, autosave: true, optional: true

    before_validation :hand_owner_to_entity, on: :create

    # The cascade runs from the entity to the record, not back: a record that
    # goes takes its entity along.
    after_destroy { Core::Entity.where(id:).delete_all }

    # Scopes on the trash state.
    #
    # Explicit, never a default scope. The join is with the entity, which holds
    # the state.
    scope :kept, -> { joins(:entity).merge(Core::Entity.kept) }
    scope :trashed, -> { joins(:entity).merge(Core::Entity.trashed) }

    # Trash state of the record.
    #
    # Delegated to the entity, so the entity must be preloaded
    # (`includes(:entity)`) wherever the state is asked for.
    delegate :deleted_at, :trashed?, :trash, :restore, to: :entity

    # A new record builds its entity on first use.
    def entity = super || (build_entity(record_type: self.class.base_class.name) if new_record?)
  end

  private

  def hand_owner_to_entity = entity.user_id = user_id
end
