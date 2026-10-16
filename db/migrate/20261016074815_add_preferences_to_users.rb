class AddPreferencesToUsers < ActiveRecord::Migration[8.1]
  def change
    change_table :users, bulk: true do |t|
      t.string :locale
      t.string :date_format
      t.integer :first_weekday
      t.string :time_format
      t.string :time_zone
      t.string :theme
      t.string :detected_time_zone
    end

    # A CHECK passes for NULL, so every preference may stay automatic.
    # Locale has only a shape check: the supported list is configuration, validated in the model.
    add_check_constraint :users, "locale GLOB '[a-z][a-z]'", name: "chk_users_locale_shape"
    add_check_constraint :users, "date_format IN ('dmy', 'mdy', 'ymd')", name: "chk_users_date_format"
    add_check_constraint :users, "first_weekday BETWEEN 0 AND 6", name: "chk_users_first_weekday"
    add_check_constraint :users, "time_format IN ('12h', '24h')", name: "chk_users_time_format"
    add_check_constraint :users, "theme IN ('light', 'dark')", name: "chk_users_theme"
  end
end
