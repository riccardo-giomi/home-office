class CreateCoreLinks < ActiveRecord::Migration[8.1]
  def change
    # Two entities of one user, stored once with the lower id first. A link
    # has no data of its own.
    create_table :core_links do |t|
      t.integer :first_entity_id, null: false
      t.integer :second_entity_id, null: false
      t.integer :user_id, null: false
      t.datetime :created_at, null: false

      t.foreign_key :core_entities, column: [:first_entity_id, :user_id], primary_key: [:id, :user_id], on_delete: :cascade
      t.foreign_key :core_entities, column: [:second_entity_id, :user_id], primary_key: [:id, :user_id], on_delete: :cascade
      t.check_constraint "first_entity_id < second_entity_id", name: "chk_core_links_ordered"
    end
    add_index :core_links, [:first_entity_id, :second_entity_id], unique: true, name: "index_core_links_pair"
    add_index :core_links, :second_entity_id
  end
end
