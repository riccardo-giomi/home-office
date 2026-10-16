class CreateCoreEntities < ActiveRecord::Migration[8.1]
  def change
    create_table :core_entities do |t|
      t.references :user, null: false, foreign_key: {on_delete: :cascade}, index: false
      t.string :record_type, null: false

      t.timestamps
    end

    # SQLite lets a foreign key point only at columns that are the primary key
    # or have a unique index together.
    # All of these will be needed one way or the other.
    add_index :core_entities, [:id, :user_id], unique: true
    add_index :core_entities, [:id, :record_type], unique: true
    add_index :core_entities, [:id, :user_id, :record_type], unique: true
  end
end
