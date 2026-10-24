class AddDeletedAtToCoreEntities < ActiveRecord::Migration[8.1]
  def change
    add_column :core_entities, :deleted_at, :datetime

    # Partial: only the trash is ever searched by this column, and most
    # entities are not in it.
    add_index :core_entities, [:user_id, :deleted_at],
      name: "index_core_entities_trash", where: "deleted_at IS NOT NULL"
    add_index :core_entities, :deleted_at,
      name: "index_core_entities_purge", where: "deleted_at IS NOT NULL"
  end
end
