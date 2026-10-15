class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false

      t.timestamps
    end
    add_index :users, :email_address, unique: true
    add_check_constraint :users, "email_address = lower(trim(email_address))", name: "chk_users_email_normalized"
  end
end
